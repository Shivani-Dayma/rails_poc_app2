class GeneralFileParserWorker
  include Sidekiq::Worker

  def perform(general_file_id)
    file = GeneralFile.find(general_file_id)
    parsed_data = GeneralFileParserService.new(file).process!

    return unless parsed_data.is_a?(Array)

    parsed_data.each do |row|
      file.extracted_records.create!(data: row)
    end
  end
end