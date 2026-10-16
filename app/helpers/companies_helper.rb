module CompaniesHelper
  def company_edit_button
    return unless can?(:update, :company)

    link_to edit_company_path, class: 'btn btn-outline-secondary btn-round' do
      concat icon(:pencil, class: 'me-2')
      concat t('companies.show.edit')
    end
  end

  def company_secret_badge(value)
    return status_badge(t('companies.show.configured'), kind: :success) if value.present?

    status_badge(t('companies.show.not_configured'), kind: :warning)
  end
end
