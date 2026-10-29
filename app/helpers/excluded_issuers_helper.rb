module ExcludedIssuersHelper
  def excluded_issuers_menu(excluded_issuer)
    menus = []

    menus << excluded_issuer_destroy_menu(excluded_issuer) if can?(:destroy, :excluded_issuers)

    menus
  end

  def excluded_issuer_create_button
    create_button(t('excluded_issuers.index.new_excluded_issuer')) if can?(:create, :excluded_issuers)
  end

  private

  def excluded_issuer_destroy_menu(excluded_issuer)
    Menu.new(
      name: :destroy,
      record: excluded_issuer,
      url: excluded_issuer_path(excluded_issuer),
      icon: :'x-circle',
      data: {
        turbo_confirm: t('excluded_issuers.index.confirm_destroy'),
        turbo_method: :delete,
      },
    )
  end
end
