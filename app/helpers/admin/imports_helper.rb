module Admin
  module ImportsHelper
    STATUS_KINDS = { 'pending' => :secondary, 'running' => :warning, 'succeeded' => :success, 'failed' => :danger }.freeze

    def admin_import_menu(import)
      menus = []

      menus << admin_import_download_menu(import) if import.file.attached?
      menus << admin_import_reprocess_menu(import) if import.file.attached? && !import.running?

      menus
    end

    def admin_import_actions(import)
      menus = admin_import_menu(import)
      return t('admin.imports.index.blank') if menus.empty?

      responsive_actions_menu(menus)
    end

    def admin_imports_action_required(imports)
      return if imports.none?

      render('admin/imports/action_required', imports:)
    end

    def admin_import_status_badge(import)
      status_badge(import.status_type_name, kind: STATUS_KINDS.fetch(import.status_type))
    end

    def admin_import_period(import)
      return t('admin.imports.index.whole_registry') unless import.period?

      t('admin.imports.index.period', start_date: l(import.start_date), end_date: l(import.end_date))
    end

    def admin_import_counts(import)
      t('admin.imports.index.counts', read: import.rows_read, inserted: import.inserted_count,
                                      updated: import.updated_count, removed: import.removed_count)
    end

    def admin_import_duration(import)
      seconds = import.duration&.round
      return t('admin.imports.index.blank') unless seconds

      format('%<hours>d:%<minutes>02d:%<seconds>02d', hours: seconds / 3600, minutes: (seconds % 3600) / 60, seconds: seconds % 60)
    end

    def admin_import_action_required_badge(import)
      return unless import.action_required?

      content_tag :span, class: 'badge text-bg-danger d-inline-flex align-items-center gap-1 mt-1' do
        concat icon(:'exclamation-octagon-fill')
        concat t('admin.imports.index.action_required', error: import.error_type_name)
      end
    end

    def admin_import_message(import)
      return content_tag(:span, import.error_message, class: admin_import_error_class(import)) if import.failed?
      return content_tag(:span, import.warning_message, class: 'text-warning-emphasis small') if import.warning_message.present?

      t('admin.imports.index.blank')
    end

    def admin_tenant_flag_badge(tenant_status)
      return status_badge(t('admin.imports.overview.enabled'), kind: :success) if tenant_status.enabled?

      status_badge(t('admin.imports.overview.disabled'), kind: :secondary)
    end

    def admin_report_freshness(report_status)
      content_tag :span, class: report_status.late? ? 'text-danger fw-semibold' : 'text-body' do
        concat icon(:'exclamation-triangle-fill', class: 'me-1') if report_status.late?
        concat admin_last_succeeded_at(report_status)
      end
    end

    def admin_report_freshness_class(report_status)
      report_status.late? ? 'report-freshness report-freshness-late' : 'report-freshness'
    end

    def admin_report_name(report_type)
      Atua::Import.human_enum_name(:report_type, report_type)
    end

    def admin_report_type_options
      Atua::Import.enum_options_for_select(:report_type)
    end

    private

    def admin_last_succeeded_at(report_status)
      return t('admin.imports.overview.never') unless report_status.last_succeeded_at

      l(report_status.last_succeeded_at, format: :short)
    end

    def admin_import_error_class(import)
      import.action_required? ? 'text-danger fw-semibold small' : 'text-danger small'
    end

    def admin_import_download_menu(import)
      Menu.new(name: :download, record: import, url: download_admin_import_path(import), icon: :download, data: { turbo: false })
    end

    def admin_import_reprocess_menu(import)
      Menu.new(
        name: :reprocess,
        record: import,
        url: reprocess_admin_import_path(import),
        icon: :'arrow-repeat',
        data: {
          turbo_confirm: t('admin.imports.index.confirm_reprocess'),
          turbo_method: :post,
        },
      )
    end
  end
end
