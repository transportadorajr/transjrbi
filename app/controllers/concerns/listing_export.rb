module ListingExport
  private

  def listing_page(collection)
    return collection if request.format.pdf? || request.format.xlsx?

    collection = Kaminari.paginate_array(collection) if collection.is_a?(Array)
    collection.page(params[:page])
  end

  def respond_with_listing(orientation: :portrait, xlsx: nil)
    respond_to do |format|
      format.html
      format.pdf { render typst: nil, orientation:, filename: t('.pdf.filename', time: Time.current.to_i) }
      format.xlsx { send_listing_xlsx(xlsx) } if xlsx && XlsxExport.enabled?(current_tenant)
    end
  end

  def send_listing_xlsx(relation)
    title = t('.title')
    workbook = Exports::XlsxCommand.call([Export::Sheet.new(name: title, relation:)])

    send_data workbook, type: :xlsx, disposition: 'attachment',
                        filename: t('xlsx_export.filename', title: title.parameterize, date: Date.current.iso8601)
  rescue XlsxExport::Error => e
    Rails.error.report(e)
    redirect_to url_for(request.query_parameters.symbolize_keys.merge(format: nil)), alert: t('xlsx_export.errors.failed')
  end
end
