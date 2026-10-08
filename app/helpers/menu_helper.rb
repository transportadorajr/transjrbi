module MenuHelper
  def menu_active?(menu)
    return menu.controllers.include?(controller_path) if menu.controllers.any?

    url = menu.url.to_s

    request.path == url || request.path.start_with?("#{url}/")
  end

  def submenu_active?(menu)
    menu.menus.any? { |submenu| menu_active?(submenu) }
  end
end
