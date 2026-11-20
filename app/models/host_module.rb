HostModule = Data.define(:key, :subdomain, :resources, :feature) do
  class << self
    def all
      @all ||= [
        new(key: :maintenance, subdomain: Transjrbi::MAINTENANCE_SUBDOMAIN, resources: Ability::MAINTENANCE_RESOURCES, feature: MaintenanceOrder::FEATURE),
        new(key: :hr, subdomain: Transjrbi::HR_SUBDOMAIN, resources: Ability::HR_RESOURCES, feature: Hr::FEATURE),
      ]
    end

    def find_by_subdomain(subdomain)
      all.find { |host_module| host_module.subdomain == subdomain }
    end
  end

  def enabled?(tenant)
    Flipper.enabled?(feature, tenant)
  end
end
