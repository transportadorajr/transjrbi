module ModalHelper
  def modal_title_tag(id, title, title_icon: nil)
    content_tag(:h5, class: 'modal-title', id: "#{id}_label") do
      concat icon(title_icon, class: 'me-2 text-primary') if title_icon
      concat title
    end
  end

  def modal_footer_tag(show_footer)
    return unless show_footer

    content_tag(:div, class: 'modal-footer') do
      content_for?(:footer) ? content_for(:footer) : modal_cancel_button
    end
  end

  private

  def modal_cancel_button
    button_tag t('helpers.links.cancel'), type: 'button', class: 'btn btn-outline-secondary btn-round', data: { bs_dismiss: 'modal' }
  end
end
