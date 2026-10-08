require 'delegate'

class Menu < SimpleDelegator
  class << self
    def find_and_wrap(namespace, *path, **)
      wrap(dig(namespace, *path)[:menus], **)
    end

    def dig(namespace, *path)
      initial = menus_config[namespace].is_a?(Hash) ? menus_config[namespace] : { menus: menus_config[namespace] }
      path.reduce(initial) { |parent, name| parent[:menus].find { |m| m[:name] == name } }
    end

    def menus_config
      @menus_config ||= YAML.load_file(Rails.root.join('config', 'menu.yml'))['shared'].with_indifferent_access
    end

    def wrap(menus, **)
      return unless menus

      menus.map { |menu| Menu.new(**menu.with_indifferent_access, **) }
    end
  end

  def initialize(**menu)
    super(menu.with_indifferent_access)
  end

  def name
    I18n.t(self[:name], scope: :menus)
  end

  def menus
    Menu.wrap(self[:menus]) || []
  end

  def url
    self[:url] || { action: self[:name], id: self[:record] }.compact
  end

  def icon
    self[:icon]
  end

  def controllers
    Array(self[:controllers] || self[:controller])
  end

  def data
    self[:data]
  end

  def show?
    menus.empty? || menus.any?(&:show?)
  end
end
