module PaginationHelper
  def pagination_prev_tag(paginator, current_page)
    paginator.prev_page_tag unless current_page.first?
  end

  def pagination_next_tag(paginator, current_page)
    paginator.next_page_tag unless current_page.last?
  end

  def pagination_window_tag(paginator, page)
    return paginator.page_tag(page) if page.left_outer? || page.right_outer? || page.inside_window?

    paginator.gap_tag unless page.was_truncated?
  end

  def pagination_page_item(page, url, remote)
    return pagination_current_page_item(page, remote) if page.current?

    content_tag :li, class: 'page-item' do
      link_to page, url, remote:, rel: page.rel, class: 'page-link text-primary'
    end
  end

  private

  def pagination_current_page_item(page, remote)
    content_tag :li, class: 'page-item active' do
      link_to page, '#', class: 'page-link bg-primary border-primary', data: { remote: }, rel: page.rel, aria: { current: 'page' }
    end
  end
end
