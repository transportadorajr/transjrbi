module SuppliersHelper
  def suppliers_menu(supplier)
    menus = []

    menus << supplier_edit_menu(supplier) if can?(:update, :suppliers)

    menus
  end

  def supplier_status_badge(supplier)
    if supplier.active?
      status_badge(t('suppliers.status.active'), kind: :success)
    else
      status_badge(t('suppliers.status.inactive'), kind: :danger)
    end
  end

  def supplier_form_url(supplier_form)
    supplier_form.persisted? ? supplier_path(supplier_form.supplier) : suppliers_path
  end

  def supplier_form_submit_label(supplier_form)
    t("helpers.submit.supplier.#{supplier_form.persisted? ? :update : :create}")
  end

  def supplier_create_button
    create_button(t('suppliers.index.new_supplier')) if can?(:create, :suppliers)
  end

  private

  def supplier_edit_menu(supplier)
    Menu.new(name: :edit, record: supplier, url: edit_supplier_path(supplier), icon: :pencil)
  end
end
