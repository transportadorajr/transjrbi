class Ability
  include CanCan::Ability

  MAINTENANCE_RESOURCES = %i[maintenance maintenance_orders workshop_employees suppliers vehicles].freeze

  def initialize(user, resources: nil)
    return unless user

    @resources = resources

    can %i[read update], User, id: user.id

    access_privileges(user)

    return if user.operator?

    can %i[read create update], User, tenant_id: user.tenant_id
    can :deactivate, User, tenant_id: user.tenant_id
    cannot :deactivate, User, user_type: 'owner'
    cannot :deactivate, User, id: user.id
    return unless user.owner?

    can :confirm, User, tenant_id: user.tenant_id, confirmed_at: nil
    resource_privileges
  end

  private

  def access_privileges(user)
    user.accesses.preload(:resource).find_each do |access|
      can(access.abilities, access.resource_symbol) if access.abilities.any? && resource_allowed?(access.resource_symbol)
    end
  end

  def resource_privileges
    Resource.pluck(:slug).map(&:to_sym).select { |slug| resource_allowed?(slug) }.each { |slug| can(:manage, slug) }
  end

  def resource_allowed?(slug)
    @resources.nil? || @resources.include?(slug)
  end
end
