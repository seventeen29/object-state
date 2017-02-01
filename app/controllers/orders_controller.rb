require 'csv'

class OrdersController < ApplicationController
  before_action :set_order, only: [:show, :edit, :update, :destroy, :upload, :do_upload, :resume_upload, :update_status, :reset_upload]

  # GET /orders
  # GET /orders.json
  def index
    @orders = Order.all.order(name: :asc)
  end

  # GET /orders/1
  # GET /orders/1.json
  def show
    # If upload is not commenced or finished, redirect to upload page
    return redirect_to upload_order_path(@order) if @order.status.in?(%w(new uploading))
  end

  # GET /orders/new
  def new
    @order = Order.new(name: SecureRandom.hex, status: 'new')
    respond_to do |format|
      if @order.save
        format.html { redirect_to upload_order_path(@order) }
        format.json { render :show, status: :created, location: @order }
      else
        format.html { render :new }
        format.json { render json: @order.errors, status: :unprocessable_entity }
      end
    end
  end

  # GET /orders/1/edit
  def edit
  end

  # POST /orders
  # POST /orders.json
  def create
    @order = Order.new(order_params)
    @order.status = 'new'

    respond_to do |format|
      if @order.save
        format.html { redirect_to upload_order_path(@order), notice: 'Order was successfully created.' }
        format.json { render :show, status: :created, location: @order }
      else
        format.html { render :new }
        format.json { render json: @order.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /orders/1
  # PATCH/PUT /orders/1.json
  def update
    @order.assign_attributes(status: 'new', upload: nil) if params[:delete_upload] == 'yes'

    respond_to do |format|
      if @order.update(order_params)
        format.html { redirect_to @order, notice: 'Order was successfully updated.' }
        format.json { render :show, status: :ok, location: @order }
      else
        format.html { render :edit }
        format.json { render json: @order.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /orders/1
  # DELETE /orders/1.json
  def destroy
    @order.destroy
    respond_to do |format|
      format.html { redirect_to orders_url, notice: 'Order was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  # GET /orders/:id/upload
  def upload

  end

  # PATCH /orders/:id/upload.json
  def do_upload
    unpersisted_order = Order.new(upload_params)

    Rails.logger.info "1"
    # If no file has been uploaded or the uploaded file has a different filename,
    # do a new upload from scratch
    if @order.upload_file_name != unpersisted_order.upload_file_name
      @order.assign_attributes(upload_params)
      @order.status = 'uploading'
      @order.save!
      write_events
      render json: @order.to_jq_upload and return

    # If the already uploaded file has the same filename, try to resume
    else
      current_size = @order.upload_file_size
      content_range = request.headers['CONTENT-RANGE']
      begin_of_chunk = content_range[/\ (.*?)-/,1].to_i # "bytes 100-999999/1973660678" will return '100'

      # If the there is a mismatch between the size of the incomplete upload and the content-range in the
      # headers, then it's the wrong chunk!
      # In this case, start the upload from scratch
      unless begin_of_chunk == current_size
        @order.update!(upload_params)
        render json: @order.to_jq_upload and return
      end

      # Add the following chunk to the incomplete upload
      File.open(@order.upload.path, "ab") { |f| f.write(upload_params[:upload].read) }

      # Update the upload_file_size attribute
      @order.upload_file_size = @order.upload_file_size.nil? ? unpersisted_order.upload_file_size : @order.upload_file_size + unpersisted_order.upload_file_size
      @order.save!

      write_events
      render json: @order.to_jq_upload and return
    end
  end

  # GET /orders/:id/reset_upload
  def reset_upload
    # Allow users to delete uploads only if they are incomplete
    raise StandardError, "Action not allowed" unless @order.status == 'uploading'
    @order.update!(status: 'new', upload: nil)
    redirect_to @order, notice: "Upload reset successfully. You can now start over"
  end

  # GET /orders/:id/resume_upload.json
  def resume_upload
    render json: { file: { name: @order.upload.url(:default, timestamp: false), size: @order.upload_file_size } } and return
  end

  # PATCH /orders/:id/update_upload_status
  def update_status
    raise ArgumentError, "Wrong status provided " + params[:status] unless @order.status == 'uploading' && params[:status] == 'uploaded'
    @order.update!(status: params[:status])
    head :ok
  end


  private
  # Use callbacks to share common setup or constraints between actions.
  def set_order
    @order = Order.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def order_params
    params.require(:order).permit(:name)
  end

  def upload_params
    params.require(:order).permit(:upload)
  end

  def write_events
    header = []
    Rails.logger.info @order.upload.path
    #CSV.foreach(@order.upload.path, headers: true) do | row |
    #  Rails.logger.debug row
    #end
    File.foreach(@order.upload.path) do |line|
      row = CSV.parse(line.gsub('\"', '""')).first

      if header.empty?
        header = row.map(&:to_sym)
        next
      end
      row = Hash[header.zip(row)]
      Rails.logger.debug row
      row[:order_id] = @order.id
      object_changes = JSON.parse(row[:object_changes]) rescue nil
      if object_changes.nil?
        Rails.logger.debug("Ignoring line: #{line}")
        next
      end
      row[:object_changes] = Hash[object_changes.map { |k, v| [k.downcase, v]}]
      row[:object_type] = row[:object_type].downcase
      event = Event.new(row)
      event.save
    end

    create_event_snapshots
  end

  def create_event_snapshots
    current_object_id = nil
    current_object_type = nil
    current_state = {}
    Event.where(order_id: @order.id).order(:object_type, :object_id, :timestamp).each do |row|
      object_id = row['object_id']
      object_type = row['object_type'].downcase
      object_state = row['object_changes']
      timestamp = row['timestamp']

      Rails.logger.info "#{object_state},  #{object_type}, #{object_id}"
      if current_object_id.nil? || current_object_type.nil?
        current_object_id = object_id
        current_object_type = object_type
      end

      if current_object_id != object_id || current_object_type != object_type
        current_object_type = object_type
        current_object_id = object_id
        current_state = object_state
      else
        current_state = current_state.merge(object_state)
      end
      event_state = Eventstate.new(object_id: object_id, object_type: object_type, object_changes: current_state, timestamp: timestamp, order_id: @order.id)
      event_state.save
    end
  end
end
