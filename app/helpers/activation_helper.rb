module ActivationHelper
  def activation_menu(record, active:, namespace: nil)
    action = active ? :deactivate : :activate

    Menu.new(
      name: action,
      record:,
      url: polymorphic_path([namespace, record].compact, action:),
      icon: active ? :'slash-circle' : :'check-circle',
      data: {
        turbo_confirm: t("shared.activation.confirm_#{action}"),
        turbo_method: :patch,
      },
    )
  end

  def activation_status_label(scope, active)
    t(active ? :active : :deactivated, scope: [*scope, :index])
  end

  def activation_status_badge(scope, active)
    status_badge(activation_status_label(scope, active), kind: active ? :success : :danger)
  end
end
