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

    # Separate header and table records
    all_records = @general_file.extracted_records.active
    header_record = all_records.find { |record| record.data['record_type'] == 'header' }
    table_records = all_records.reject { |record| record.data['record_type'] == 'header' }

    respond_to do |format|
      format.html # renders show.html.erb
      format.json {
        render json: {
          id: @general_file.id,
          file_name: @general_file.file_name,
          uploaded_at: @general_file.created_at,
          # Include header information from the header record
          header_info: header_record&.data || {},
          extracted_records: table_records.map(&:data),
          # Add column order for consistent display
          column_order: get_column_order
        }
      }
    end
  end

  def download_excel
    general_file = GeneralFile.active.find(params[:id])
    # Only get table records, exclude header records for Excel export
    table_records = general_file.extracted_records.active
                                .reject { |record| record.data['record_type'] == 'header' }
                                .map(&:data)

    if table_records.blank?
      render json: { error: "No extracted data found for this file." }, status: :not_found
      return
    end

    file_path = generate_excel(table_records)
    send_file file_path,
              filename: "extracted_records_#{general_file.id}.xlsx",
              type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  def download_file
    @general_file = GeneralFile.active.find(params[:id])
    send_data @general_file.file.download,
              filename: @general_file.file_name.to_s,
              type: @general_file.file.content_type,
              disposition: 'attachment'
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

    # Use consistent column order
    column_order = get_column_order

    Axlsx::Package.new do |p|
      p.workbook.add_worksheet(name: "Extracted Data") do |sheet|
        # Add header row in correct order
        sheet.add_row column_order

        # Add data rows in correct order
        data.each do |row|
          sheet.add_row column_order.map { |col| row[col] || "" }
        end
      end
      p.serialize(file_path.to_s)
    end
    file_path
  end

  def get_column_order
    [
      "Farm", "Tract", "CLU/Field", "Crop/Comm", "Var/Type", "Int Use",
      "Act Use", "Irr Pr.", "Org Stat", "Nat. Sod", "C/C Stat", "Rpt Unit",
      "Rpt Qty", "Det Qty", "Crop Land", "Planting Date", "P/P", "End Date",
      "Producer Share", "Producer Name", "FSA Physical Location", "NAP Unit",
      "Signature Date", "Field ID"
    ]
  end

  def file_params
    params.permit(:file_name)
  end
end
