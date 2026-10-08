class Ability
  include CanCan::Ability

  def initialize(user)
    return unless user

    can %i[read update], User, id: user.id

    return if user.operator?

    can %i[read create update], User, tenant_id: user.tenant_id
  end
end
