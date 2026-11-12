module ListingExport
  private

  def listing_page(collection)
    return collection if request.format.pdf? || request.format.xlsx?

    collection = Kaminari.paginate_array(collection) if collection.is_a?(Array)
    collection.page(params[:page])
  end

  def respond_with_listing(orientation: :portrait, pdf: true, xlsx: nil)
    respond_to do |format|
      format.html
      format.pdf { render typst: nil, orientation:, filename: t('.pdf.filename', time: Time.current.to_i) } if pdf
      format.xlsx { send_listing_xlsx(xlsx) } if xlsx && XlsxExport.enabled?(current_tenant)
    end
  end

  def send_listing_xlsx(xlsx)
    title = t('.title')
    workbook = Exports::XlsxCommand.call(listing_sheets(xlsx, title))

    send_data workbook, type: :xlsx, disposition: 'attachment',
                        filename: t('xlsx_export.filename', title: title.parameterize, date: Date.current.iso8601)
  rescue XlsxExport::Error => e
    Rails.error.report(e)
    redirect_to url_for(request.query_parameters.symbolize_keys.merge(format: nil)), alert: t('xlsx_export.errors.failed')
  end

  def listing_sheets(xlsx, title)
    xlsx = xlsx.call if xlsx.respond_to?(:call)
    return [Export::Sheet.for(xlsx, name: title)] if xlsx.is_a?(ActiveRecord::Relation)

    Array(xlsx)
  end
end
