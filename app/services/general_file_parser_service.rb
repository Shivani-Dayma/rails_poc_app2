# app/services/general_file_parser_service.rb
class GeneralFileParserService
  require "base64"

  def initialize(general_file)
    @general_file = general_file
  end

  def process!
    base64_content = encode_file
    return unless base64_content

    # Extract header information first and save as a record
    header_data = extract_header_information(base64_content)
    save_header_record(header_data) if header_data

    # Then extract table data (existing flow)
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

  def extract_header_information(base64_content)
    prompt = build_header_extraction_prompt
    response = send_gemini_request(base64_content, prompt)

    if response
      header_data = parse_header_response(response)
      Rails.logger.info "Header extraction: Successfully extracted header information"
      header_data
    else
      Rails.logger.error "Header extraction failed"
      nil
    end
  end

  def build_header_extraction_prompt
    <<~PROMPT
      You are looking at an FSA form. I need you to extract ONLY the header/form information (NOT the table data).

      **Extract these specific header fields:**

      1. Form Type (like "FSA - 578" or similar form identifier)
      2. Producer Name (the main producer name, usually prominent at the top)
      3. Producer Address (complete address including street, city, state, zip)
      4. Farm Number (usually a 4-digit number like 3655)
      5. Tract Number (usually a 4-digit number like 2302)
      6. Program Year (if mentioned)
      7. County Office (FSA county office location)
      8. Legal Description (the legal land description, often contains sections, townships)
      9. Total Farmland (acreage numbers)
      10. Total Cropland (acreage numbers)
      11. Reported Cropland (acreage numbers)
      12. OMB Control Number (like "0560-0175")
      13. Estimated Response Time (like "15 minutes")
      14. Privacy Act Reference (like "Privacy Act of 1974")
      15. Legal Authority (key acts mentioned like "Farm Security and Rural Investment Act")

      **OUTPUT FORMAT:**
      Return the information in this exact format (one field per line):

      FORM_TYPE: [value or BLANK]
      PRODUCER_NAME: [value or BLANK]
      PRODUCER_ADDRESS: [value or BLANK]
      FARM_NUMBER: [value or BLANK]
      TRACT_NUMBER: [value or BLANK]
      PROGRAM_YEAR: [value or BLANK]
      COUNTY_OFFICE: [value or BLANK]
      LEGAL_DESCRIPTION: [value or BLANK]
      TOTAL_FARMLAND: [value or BLANK]
      TOTAL_CROPLAND: [value or BLANK]
      REPORTED_CROPLAND: [value or BLANK]
      OMB_CONTROL_NUMBER: [value or BLANK]
      RESPONSE_TIME: [value or BLANK]
      PRIVACY_ACT: [value or BLANK]
      LEGAL_AUTHORITY: [value or BLANK]

      **IMPORTANT:**
      - Only extract information from the header/form areas, NOT from data tables
      - If a field is not found or unclear, use "BLANK"
      - Be precise with numbers and text
      - For addresses, combine all address lines into one field
      - For legal authority, summarize key acts mentioned (not the full text)
    PROMPT
  end

  def parse_header_response(response_text)
    return {} if response_text.blank?

    header_data = {}

    lines = response_text.split("\n")
    lines.each do |line|
      line = line.strip
      next if line.empty?

      if line.include?(':')
        key, value = line.split(':', 2)
        key = key.strip.downcase.gsub('_', '_')
        value = value.strip

        # Convert to our expected field names
        case key
        when 'form_type'
          header_data[:form_type] = value == 'BLANK' ? nil : value
        when 'producer_name'
          header_data[:producer_name] = value == 'BLANK' ? nil : value
        when 'producer_address'
          header_data[:producer_address] = value == 'BLANK' ? nil : value
        when 'farm_number'
          header_data[:farm_number] = value == 'BLANK' ? nil : value
        when 'tract_number'
          header_data[:tract_number] = value == 'BLANK' ? nil : value
        when 'program_year'
          header_data[:program_year] = value == 'BLANK' ? nil : value
        when 'county_office'
          header_data[:county_office] = value == 'BLANK' ? nil : value
        when 'legal_description'
          header_data[:legal_description] = value == 'BLANK' ? nil : value
        when 'total_farmland'
          header_data[:total_farmland] = value == 'BLANK' ? nil : value
        when 'total_cropland'
          header_data[:total_cropland] = value == 'BLANK' ? nil : value
        when 'reported_cropland'
          header_data[:reported_cropland] = value == 'BLANK' ? nil : value
        when 'omb_control_number'
          header_data[:omb_control_number] = value == 'BLANK' ? nil : value
        when 'response_time'
          header_data[:response_time] = value == 'BLANK' ? nil : value
        when 'privacy_act'
          header_data[:privacy_act] = value == 'BLANK' ? nil : value
        when 'legal_authority'
          header_data[:legal_authority] = value == 'BLANK' ? nil : value
        end
      end
    end

    Rails.logger.info "Parsed header data: #{header_data.inspect}"
    header_data
  end

  def save_header_record(header_data)
    # Add a special identifier to mark this as header data
    header_record_data = header_data.merge(record_type: 'header')

    @general_file.extracted_records.create!(data: header_record_data)
    Rails.logger.info "Saved header information as extracted record"
  rescue => e
    Rails.logger.error "Failed to save header information: #{e.message}"
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
      21. FSA Physical Location
      22. NAP Unit
      23. Signature Date
      24. Field ID

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

    _field_1a_records = records.select { |r| r["CLU/Field"] == "1A" }
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
      "Producer Name" => clean_value(values[19]),
      "FSA Physical Location" => clean_value(values[20]),
      "NAP Unit" => clean_value(values[21]),
      "Signature Date" => clean_value(values[22]),
      "Field ID" => clean_value(values[23])
    }

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

    cleaned = cleaned.gsub(/["""]/, '"')
    cleaned = cleaned.gsub(/\s+/, ' ')

    cleaned
  end

  def has_essential_data?(record)
    essential_fields = ["CLU/Field", "Crop/Comm"]
    essential_present = essential_fields.all? { |field| !record[field].empty? }

    non_empty_count = record.values.count { |v| !v.empty? }

    essential_present && non_empty_count >= 6
  end
end
