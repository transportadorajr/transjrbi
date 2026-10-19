module Admin
  module HttpRequestsHelper
    STATUS_KINDS = { 2 => :success, 3 => :info, 4 => :warning, 5 => :danger }.freeze

    def admin_http_request_menu(http_request)
      [Menu.new(name: :show, record: http_request, url: admin_http_request_path(http_request), icon: :eye)]
    end

    def admin_http_request_status_badge(http_request)
      return status_badge(t('admin.http_requests.index.no_response'), kind: :danger) unless http_request.status_code

      status_badge(admin_http_request_status_label(http_request), kind: STATUS_KINDS.fetch(http_request.status_code / 100, :secondary))
    end

    def admin_http_request_status_label(http_request)
      [http_request.status_code, http_request.status_message].compact.join(' ')
    end

    def admin_http_request_path_label(http_request)
      uri = URI.parse(http_request.url)
      [uri.host, uri.path].join
    rescue URI::InvalidURIError
      http_request.url
    end

    def admin_http_request_duration(http_request)
      return t('admin.http_requests.index.blank') unless http_request.duration_ms

      t('admin.http_requests.index.duration', value: number_with_delimiter(http_request.duration_ms))
    end

    def admin_http_request_tenant(http_request)
      http_request.tenant&.trade_name || t('admin.http_requests.index.blank')
    end

    def admin_http_request_import_link(http_request)
      return t('admin.http_requests.index.blank') unless http_request.atua_import

      link_to(http_request.atua_import.report_type_name, admin_http_requests_path(atua_import_id: http_request.atua_import_id))
    end

    def admin_http_request_error(http_request)
      return t('admin.http_requests.index.blank') unless http_request.error_class

      content_tag(:span, [http_request.error_class, http_request.error_message].compact_blank.join(': '), class: 'text-danger')
    end

    def admin_http_request_pairs(pairs)
      return content_tag(:p, t('admin.http_requests.show.empty'), class: 'text-muted mb-0') if pairs.blank?

      render('admin/http_requests/pairs', pairs:)
    end

    def admin_http_request_headers(headers)
      admin_http_request_pairs(headers.sort)
    end

    def admin_http_request_request_body(http_request)
      admin_http_request_body(http_request.request_body)
    end

    def admin_http_request_response_body(http_request)
      return admin_http_request_notice(t('admin.http_requests.show.no_response')) unless http_request.status_code

      if http_request.response_binary?
        return admin_http_request_notice(
          t('admin.http_requests.show.binary', content_type: http_request.response_content_type, size: number_to_human_size(http_request.response_size)),
        )
      end

      safe_join([admin_http_request_truncated_notice(http_request), admin_http_request_body(http_request.formatted_response_body)].compact)
    end

    def admin_http_request_chain(chain, current)
      return unless chain.many?

      render('admin/http_requests/chain', chain:, current:)
    end

    def admin_http_request_params_tab(id, params)
      return unless params

      content_tag :li, class: 'nav-item', role: :presentation do
        button_tag(t('admin.http_requests.show.params'), type: :button, class: 'nav-link text-nowrap', role: :tab,
                                                         data: { bs_toggle: :tab, bs_target: "##{id}_params" })
      end
    end

    def admin_http_request_params_pane(id, params)
      return unless params

      content_tag :div, class: 'tab-pane fade', id: "#{id}_params", role: :tabpanel do
        concat content_tag(:h3, t('admin.http_requests.show.params'), class: 'h6 fw-semibold')
        concat admin_http_request_pairs(params)
      end
    end

    def admin_http_request_chain_item(item, current)
      label = safe_join([
        content_tag(:span, "#{item.http_method} #{URI.parse(item.url).path}", class: 'fw-semibold d-block text-break'),
        content_tag(:span, admin_http_request_status_label(item).presence || t('admin.http_requests.index.no_response'), class: 'small'),
      ], ' ')
      return content_tag(:span, label, class: 'list-group-item active', aria: { current: 'step' }) if item == current

      link_to(label, admin_http_request_path(item), class: 'list-group-item list-group-item-action')
    end

    private

    def admin_http_request_body(body)
      return admin_http_request_notice(t('admin.http_requests.show.empty_body')) if body.blank?

      content_tag(:pre, body, class: 'http-request-body mb-0')
    end

    def admin_http_request_truncated_notice(http_request)
      return unless http_request.response_truncated?

      content_tag(:p, t('admin.http_requests.show.truncated', size: number_to_human_size(http_request.response_size)), class: 'text-warning-emphasis small')
    end

    def admin_http_request_notice(text)
      content_tag(:p, text, class: 'text-muted mb-0')
    end
  end
end
