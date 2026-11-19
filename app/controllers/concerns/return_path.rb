module ReturnPath
  extend ActiveSupport::Concern

  included do
    helper_method :return_path
  end

  private

  def return_path(fallback)
    safe_return_path(params[:return_to]) || fallback
  end

  def referer_return_path
    referer = URI.parse(request.referer.to_s)
    return if referer.host != request.host

    safe_return_path(referer.request_uri)
  rescue URI::InvalidURIError
    nil
  end

  def safe_return_path(path)
    path = path.to_s
    return unless path.start_with?('/') && !path.start_with?('//') && path.exclude?('\\')
    return if URI.parse(path).path == request.path

    path
  rescue URI::InvalidURIError
    nil
  end
end
