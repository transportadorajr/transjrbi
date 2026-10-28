class Ability
  include CanCan::Ability

  def initialize(user)
    return unless user

    can %i[read update], User, id: user.id

    access_privileges(user)

    return if user.operator?

    can %i[read create update], User, tenant_id: user.tenant_id
    can :deactivate, User, tenant_id: user.tenant_id
    cannot :deactivate, User, user_type: 'owner'
    cannot :deactivate, User, id: user.id
    resource_privileges
  end

  private

  def access_privileges(user)
    user.accesses.preload(:resource).find_each do |access|
      can(access.abilities, access.resource_symbol) if access.abilities.any?
    end
  end

  def resource_privileges
    Resource.pluck(:slug).each { |slug| can(:manage, slug.to_sym) }
  end
end
