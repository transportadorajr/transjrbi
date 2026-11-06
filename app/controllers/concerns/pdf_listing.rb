module PdfListing
  private

  def listing_page(collection)
    return collection if request.format.pdf?

    collection = Kaminari.paginate_array(collection) if collection.is_a?(Array)
    collection.page(params[:page])
  end

  def respond_with_listing(orientation: :portrait)
    respond_to do |format|
      format.html
      format.pdf { render typst: nil, orientation:, filename: t('.pdf.filename', time: Time.current.to_i) }
    end
  end
end
