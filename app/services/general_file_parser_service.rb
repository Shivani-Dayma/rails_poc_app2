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

      The uploaded file may contain **one or multiple records** (e.g., invoices, purchase orders, bills, etc.). Your task is to extract key-value structured data from it.

      🔸 If multiple records are present, return them as an array of hashes.
      🔸 Keys must be consistent across all records.
      🔸 If some keys are missing, set the value to null.
      🔸 Use exact keys like: "invoice_number", "date", "amount" (if found).
      🔸 Avoid duplicates if the same info is spread across pages.
      🔸 Return valid, minified JSON only. No explanation or markdown.
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
