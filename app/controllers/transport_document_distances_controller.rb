class TransportDocumentDistancesController < BaseController
  before_action :set_transport_document

  def edit
    authorize!(:update, :transport_documents)

    @transport_document_distance_form = TransportDocumentDistanceForm.for_transport_document(@transport_document)
  end

  def update
    authorize!(:update, :transport_documents)

    @transport_document_distance_form = TransportDocumentDistanceForm.new(transport_document: @transport_document, **distance_params)

    if @transport_document_distance_form.save
      redirect_to transport_document_path(@transport_document), notice: t('.success')
    else
      flash.now[:alert] = @transport_document_distance_form.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_transport_document
    @transport_document = current_tenant.atua_transport_documents.active.find(params.expect(:transport_document_id))
  end

  def distance_params
    params.expect(transport_document_distance: %i[distance_km]).to_h.symbolize_keys
  end
end
