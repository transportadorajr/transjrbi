module ProductGroupsHelper
  def product_groups_menu(product_group)
    menus = []

    menus << product_group_show_menu(product_group) if can?(:read, :product_groups)
    menus << product_group_edit_menu(product_group) if can?(:update, :product_groups)
    menus << product_group_destroy_menu(product_group) if can?(:destroy, :product_groups)

    menus
  end

  def product_filter_options(products)
    products.map { |product| [t('shared.product_option', product: product.name, group: product.parent.name), product.id.to_s] }
  end

  def product_group_status_badge(product_group)
    return status_badge(t('product_groups.index.active'), kind: :success) if product_group.activated?

    status_badge(t('product_groups.index.deactivated'), kind: :danger)
  end

  def product_group_count(product_group, counts)
    counts.fetch(product_group.id, 0)
  end

  def product_group_product_names(product_group)
    product_group.product_names.join(', ').presence || t('product_groups.show.no_product_names')
  end

  def product_group_detail_partial(product_group)
    product_group.group? ? 'product_groups/group_detail' : 'product_groups/subgroup_detail'
  end

  def product_group_unclassified_alert(products)
    return if products.none?

    render 'product_groups/unclassified_alert', products:
  end

  def product_group_create_button
    create_button(t('product_groups.index.new_product_group')) if can?(:create, :product_groups)
  end

  def product_group_create_subgroup_button(product_group)
    create_button(t('product_groups.show.new_subgroup'), new_product_group_path(parent_id: product_group.id)) if can?(:create, :product_groups)
  end

  def product_group_edit_button(product_group)
    return unless can?(:update, :product_groups)

    link_to edit_product_group_path(product_group), class: 'btn btn-outline-secondary btn-round' do
      concat icon(:pencil, class: 'me-2')
      concat t('product_groups.show.edit')
    end
  end

  def product_group_breadcrumb_items(parent, current_title)
    items = [link_to(t('product_groups.index.title'), product_groups_path)]
    items << link_to(parent.name, product_group_path(parent)) if parent

    safe_join(
      items.map { |item| content_tag(:li, item, class: 'breadcrumb-item') } +
        [content_tag(:li, current_title, class: 'breadcrumb-item active', aria: { current: 'page' })],
    )
  end

  def product_group_back_path(product_group)
    product_group.parent ? product_group_path(product_group.parent) : product_groups_path
  end

  def product_group_form_title(product_group_form)
    action = product_group_form.persisted? ? :edit : :new
    kind = product_group_form.subgroup? ? :subgroup : :group

    t("product_groups.form.titles.#{action}_#{kind}")
  end

  def product_group_form_breadcrumb_items(product_group_form)
    product_group_breadcrumb_items(product_group_form.parent, product_group_form_title(product_group_form))
  end

  def product_group_form_back_path(product_group_form)
    return product_group_path(product_group_form.product_group) if product_group_form.persisted?
    return product_group_path(product_group_form.parent) if product_group_form.parent

    product_groups_path
  end

  def product_group_form_url(product_group_form)
    product_group_form.persisted? ? product_group_path(product_group_form.product_group) : product_groups_path
  end

  def product_group_form_submit_label(product_group_form)
    t("helpers.submit.product_group.#{product_group_form.persisted? ? :update : :create}")
  end

  def product_group_form_text(product_group_form)
    t("product_groups.form.#{product_group_form.subgroup? ? :subgroup : :group}_data_text")
  end

  def product_group_product_names_field(form, product_group_form)
    return unless product_group_form.subgroup?

    render 'product_groups/product_names_field', form:, product_group_form:,
                                                 options: product_group_product_name_options(product_group_form)
  end

  def product_group_subgroups_table(subgroups, document_counts)
    return render('shared/no_content') if subgroups.none?

    render 'product_groups/subgroups_table', collection: subgroups, document_counts:
  end

  def product_group_products_table(products, table_id)
    return render('shared/no_content') if products.empty?

    render 'product_groups/products_table', products:, table_id:
  end

  private

  def product_group_product_name_options(product_group_form)
    options = product_group_form.available_product_names.map do |product_name, count|
      [t('product_groups.form.product_name_option', product_name:, count: number_with_delimiter(count)), product_name]
    end
    missing = product_group_form.product_names - options.map(&:last)

    options + missing.map { |product_name| [product_name, product_name] }
  end

  def product_group_show_menu(product_group)
    Menu.new(name: :show, record: product_group, url: product_group_path(product_group), icon: :eye)
  end

  def product_group_edit_menu(product_group)
    Menu.new(name: :edit, record: product_group, url: edit_product_group_path(product_group), icon: :pencil)
  end

  def product_group_destroy_menu(product_group)
    Menu.new(
      name: :destroy,
      record: product_group,
      url: product_group_path(product_group),
      icon: :'x-circle',
      data: {
        turbo_confirm: t('product_groups.index.confirm_destroy'),
        turbo_method: :delete,
      },
    )
  end
end
