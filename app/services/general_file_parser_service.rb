# app/services/general_file_parser_service.rb
class GeneralFileParserService
  require "base64"

  def initialize(general_file)
    @general_file = general_file
  end

  def process!
    base64_content = encode_file
    return unless base64_content

    parsed_data = extract_with_direct_approach(base64_content)
    parsed_data
  end

  private

  def encode_file
    path = @general_file.file.blob.service.send(:path_for, @general_file.file.key)
    Base64.strict_encode64(File.read(path))
  rescue => e
    Rails.logger.error("Encoding file failed: #{e.message}")
    nil
  end

  def extract_with_direct_approach(base64_content)
    prompt = build_direct_extraction_prompt
    response = send_gemini_request(base64_content, prompt)

    if response
      processed_data = parse_direct_response(response)
      Rails.logger.info "Direct extraction: Successfully processed #{processed_data.length} records"
      processed_data
    else
      nil
    end
  end

  def build_direct_extraction_prompt
    <<~PROMPT
      You are looking at an FSA form. I need you to extract data in a very specific way.

      **STEP 1: Find the main data table** (the one with crop records, not summaries)

      **STEP 2: For each row in that table, extract these exact values in order:**

      Look at each row and read from left to right, extracting:
      1. Farm number (like 3655)
      2. Tract number (like 2302)
      3. CLU/Field (like 1A, 1B)
      4. Crop name (like CORN, SOYBN)
      5. Variety (like YEL, COM)
      6. Intended Use (like GR)
      7. Actual Use (single letter, often N)
      8. Irrigation Practice (single letter, often I)
      9. Organic Status (single letter, often N)
      10. Native Sod (single letter, often C)
      11. Cover Crop Status (single letter, often A)
      12. Report Unit (often A)
      13. Reported Quantity (number like 75.50)
      14. Determined Quantity (often blank)
      15. Crop Land (like "Yes" or blank)
      16. Planting Date (MM/DD/YYYY)
      17. Planting Period (like 01)
      18. End Date (often blank)
      19. Producer Share (percentage)
      20. Producer Name

      **STEP 3: For multiple producers per crop**
      If you see multiple producers listed for one crop (like 4 different names with different percentages), create separate entries for each producer. Each gets the same crop info but different producer details.

      **OUTPUT FORMAT:**
      Return each record as a line with values separated by | (pipe character):

      Farm|Tract|CLU/Field|Crop|Variety|IntUse|ActUse|IrrPr|OrgStat|NatSod|CCStat|RptUnit|RptQty|DetQty|CropLand|PlantDate|PP|EndDate|Share|ProducerName

      **EXAMPLE:**
      3655|2302|1A|CORN|YEL|GR|N|I|N|C|A|A|75.50||Yes|04/15/2024|01||66.67|RUSSELL J REINSCH
      3655|2302|1A|CORN|YEL|GR|N|I|N|C|A|A|75.50||Yes|04/15/2024|01||11.11|JODI POOS

      **CRITICAL:**
      - If a field is blank, leave it empty between the | characters
      - Each producer gets their own line
      - Read carefully left to right to match values with positions
      - Only include Farm/Tract if they appear in that specific row

      Extract all crop records this way. Return only the pipe-separated lines.
    PROMPT
  end

  def send_gemini_request(base64_content, prompt)
    response = HTTParty.post(
      "https://generativelanguage.googleapis.com/v1/models/gemini-2.0-flash:generateContent?key=#{ENV['GOOGLE_GEMINI_API_KEY']}",
      headers: { "Content-Type" => "application/json" },
      body: {
        contents: [
          {
            parts: [
              { text: prompt },
              {
                inlineData: {
                  mimeType: @general_file.file.content_type,
                  data: base64_content
                }
              }
            ]
          }
        ],
        generationConfig: {
          temperature: 0.0,
          maxOutputTokens: 4000,
          topP: 0.1,
          topK: 1
        }
      }.to_json
    )

    if response.success?
      raw_text = JSON.parse(response.body).dig("candidates", 0, "content", "parts", 0, "text")
      Rails.logger.info "Gemini response received: #{raw_text&.length} characters"
      raw_text
    else
      Rails.logger.error "Gemini request failed: #{response.code} #{response.body}"
      nil
    end
  rescue => e
    Rails.logger.error "Gemini request error: #{e.message}"
    nil
  end

  def parse_direct_response(response_text)
    return [] if response_text.blank?

    records = []

    lines = response_text.split("\n")

    lines.each do |line|
      line = line.strip
      next if line.empty?

      next unless line.include?('|')

      values = line.split('|', -1)

      if values.length >= 19
        record = create_record_from_values(values)
        records << record if record
      else
        Rails.logger.debug "Skipped line with #{values.length} values: #{line}"
      end
    end

    fix_farm_tract_for_second_crop(records)

    Rails.logger.info "Parsed #{records.length} records from response"
    records
  end

  def fix_farm_tract_for_second_crop(records)
    return records if records.empty?

    field_1a_records = records.select { |r| r["CLU/Field"] == "1A" }
    field_1b_records = records.select { |r| r["CLU/Field"] == "1B" }

    field_1b_records.each do |record|
      record["Farm"] = ""
      record["Tract"] = ""
    end

    Rails.logger.info "Cleared Farm/Tract for #{field_1b_records.length} second crop records"
    records
  end

  def create_record_from_values(values)
    values = values + Array.new(20 - values.length, "") if values.length < 20

    record = {
      "Farm" => clean_value(values[0]),
      "Tract" => clean_value(values[1]),
      "CLU/Field" => clean_value(values[2]),
      "Crop/Comm" => clean_value(values[3]),
      "Var/Type" => clean_value(values[4]),
      "Int Use" => clean_value(values[5]),
      "Act Use" => clean_value(values[6]),
      "Irr Pr." => clean_value(values[7]),
      "Org Stat" => clean_value(values[8]),
      "Nat. Sod" => clean_value(values[9]),
      "C/C Stat" => clean_value(values[10]),
      "Rpt Unit" => clean_value(values[11]),
      "Rpt Qty" => clean_value(values[12]),
      "Det Qty" => clean_value(values[13]),
      "Crop Land" => clean_value(values[14]),
      "Planting Date" => clean_value(values[15]),
      "P/P" => clean_value(values[16]),
      "End Date" => clean_value(values[17]),
      "Producer Share" => clean_value(values[18]),
      "Producer Name" => clean_value(values[19])
    }

    # Validate record has essential data
    if has_essential_data?(record)
      record
    else
      Rails.logger.debug "Filtered out record with insufficient data"
      nil
    end
  end

  def clean_value(value)
    return "" if value.nil?

    cleaned = value.to_s.strip

    # Handle some common cleaning
    cleaned = cleaned.gsub(/["""]/, '"')  # Normalize quotes
    cleaned = cleaned.gsub(/\s+/, ' ')    # Normalize whitespace

    cleaned
  end

  def has_essential_data?(record)
    # Must have crop and field info
    essential_fields = ["CLU/Field", "Crop/Comm"]
    essential_present = essential_fields.all? { |field| !record[field].empty? }

    # Count non-empty fields
    non_empty_count = record.values.count { |v| !v.empty? }

    essential_present && non_empty_count >= 6
  end
end
