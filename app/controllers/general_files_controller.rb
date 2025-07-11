class GeneralFilesController < ApplicationController
  skip_before_action :verify_authenticity_token
  
  def index
    @general_files = GeneralFile.active.order(created_at: :desc)

    render json: @general_files.map { |file|
      {
        id: file.id,
        file_name: file.file_name
      }
    }
  end

  def create
    @general_file = GeneralFile.new(file_name: params[:file_name])
    @general_file.file.attach(params[:file])

    if @general_file.save
      GeneralFileParserWorker.perform_async(@general_file.id)

      render json: { message: 'File uploaded successfully. Processing started.', id: @general_file.id }, status: :created
    else
      render json: @general_file.errors, status: :unprocessable_entity
    end
  end

  def show
    @general_file = GeneralFile.active.find(params[:id])
  
    respond_to do |format|
      format.html # renders show.html.erb
      format.json {
        render json: {
          id: @general_file.id,
          file_name: @general_file.file_name,
          uploaded_at: @general_file.created_at,
          extracted_records: @general_file.extracted_records.active.map(&:data)
        }
      }
    end
  end



  def download_excel
    general_file = GeneralFile.active.find(params[:id])
    extracted_records = general_file.extracted_records.active.map(&:data)

    if extracted_records.blank?
      render json: { error: "No extracted data found for this file." }, status: :not_found
      return
    end

    file_path = generate_excel(extracted_records)

    send_file file_path,
              filename: "extracted_records_#{general_file.id}.xlsx",
              type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

	def destroy
		@general_file = GeneralFile.active.find(params[:id])
		@general_file.soft_delete!
		head :no_content
	end

	def update
		@general_file = GeneralFile.active.find(params[:id])
		if @general_file.update(file_params)
			render json: @general_file, status: :ok
		else
			render json: @general_file.errors, status: :unprocessable_entity
		end
	end

  private

  def generate_excel(data)
    require 'axlsx'
    file_path = Rails.root.join("tmp", "extracted_records_#{SecureRandom.hex(6)}.xlsx")

    Axlsx::Package.new do |p|
      p.workbook.add_worksheet(name: "Extracted Data") do |sheet|
        keys = data.first&.keys || []
        sheet.add_row keys
        data.each { |row| sheet.add_row keys.map { |k| row[k] } }
      end
      p.serialize(file_path.to_s)
    end

    file_path
  end

	def file_params
		params.permit(:file_name)
	end
end
