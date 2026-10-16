module Admin
  module AtuaHelper
    def admin_atua_production_access_banner
      return unless Atua.production_access?

      content_tag :div, class: 'alert alert-danger d-flex align-items-start gap-2', role: 'alert', id: 'atua-production-access' do
        concat icon(:'exclamation-octagon-fill', class: 'flex-shrink-0 mt-1')
        concat content_tag(:span, t('admin.atua.production_access_banner'))
      end
    end
  end
end
