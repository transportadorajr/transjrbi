module ExcludedIssuersHelper
  def excluded_issuers_menu(excluded_issuer)
    menus = []

    menus << excluded_issuer_destroy_menu(excluded_issuer) if can?(:destroy, :excluded_issuers)

    menus
  end

  def excluded_issuer_create_button
    create_button(t('excluded_issuers.index.new_excluded_issuer')) if can?(:create, :excluded_issuers)
  end

  def excluded_issuers_pdf_report(excluded_issuers)
    PdfReport.new(
      title: t('excluded_issuers.index.pdf.header'),
      columns: [pdf_column(ExcludedIssuer.human_attribute_name(:name), '3fr'), pdf_column(ExcludedIssuer.human_attribute_name(:code)),
                pdf_column(ExcludedIssuer.human_attribute_name(:documents_count), align: :right),
                pdf_column(ExcludedIssuer.human_attribute_name(:freight), align: :right)],
      rows: excluded_issuers.map do |excluded_issuer|
        [excluded_issuer.name, excluded_issuer.code, number_with_delimiter(excluded_issuer.documents_count), tax_money(excluded_issuer.freight)]
      end,
    )
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
