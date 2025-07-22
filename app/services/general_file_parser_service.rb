# app/services/general_file_parser_service.rb
class GeneralFileParserService
  require "base64"

  def initialize(general_file)
    @general_file = general_file
  end

  def process!
    base64_content = encode_file
    return unless base64_content

    prompt = build_prompt

    parsed_data = send_gemini_request(base64_content, prompt)
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

  def build_prompt
  <<~PROMPT
    You are an intelligent document parser.

    The uploaded file may contain one or more records (such as agricultural forms, consignment receipts, purchase orders, invoices, etc.) in formats like PDF, JPG, or PNG. Your task is to extract only the structured data that represents **actual record entries**, and return them as **rows suitable for display in a table**.

     Extraction Rules:
    - Return the data as an **array of objects**, where each object is a full row of information.
    - Include all rows that appear to represent **distinct and meaningful data entries**, even if they do not contain the same set of fields.
    - If a field contains multiple values (like multiple producers or shares), return them as a **comma-separated string** within the same field.
    - Include all available fields — if a value is not present in the document, return it as an empty string.
    - Do not extract separate tables **only containing the same columns and no new values** compared to earlier extracted records.
    - Carefully ensure short-code fields like "Act Use", "Irr Pr.", "Org Stat", "Nat. Sod", and "C/C Stat" are aligned precisely under their headers. Do not infer based on proximity.


      Do NOT include:
    - Summary tables or total-only breakdowns not tied to unique records
    - Repetitive tables with same field structure but no new values
    -  Always include the column "Planting Period" if it is present in a row. Do not omit it from the output.

     Output Format:
    - If multiple tables contain the same set of column names and similar data (e.g., repeated "Planting Period", "Crop Commodity", "Reported Quantity", etc.), extract only the first such table and completely ignore any repetitions, even if values vary slightly. Assume they are redundant summaries unless they include new identifying fields.
    - Return valid, minified JSON (no markdown or explanation).
    - Each object should be a flat key-value pair.
    - Use double quotes for all keys and values.

    Extract complete and meaningful data rows as if preparing a structured table or spreadsheet for review — and avoid fragments or layout artifacts.
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
        ]
      }.to_json
    )

    if response.success?
      raw_text = JSON.parse(response.body).dig("candidates", 0, "content", "parts", 0, "text")
      json_str = raw_text[/```json(.*?)```/m, 1]&.strip || raw_text
      JSON.parse(json_str)
    else
      Rails.logger.error "Gemini extraction failed: #{response.code} #{response.body}"
      nil
    end
  rescue => e
    Rails.logger.error "Gemini request error: #{e.message}"
    nil
  end
end
