class User < ApplicationRecord
  belongs_to :tenant

  # Módulos do Devise em uso.
  # Disponíveis para o futuro: :lockable, :timeoutable, :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :trackable

  time_based_flag :activated

  enum :user_type, %i[owner admin operator].index_with(&:to_s), validate: true

  validates :name, presence: true

  scope :by_name, ->(name) { where(arel_table[:name].matches("%#{sanitize_sql_like(name)}%")) }
  scope :by_status, ->(status) { status.to_s == 'active' ? activated : not_activated }

  class << self
    def statuses
      {
        I18n.t('users.index.active') => :active,
        I18n.t('users.index.deactivated') => :deactivated,
      }
    end
  end

  private

  # Envia os e-mails do Devise em segundo plano (fila do GoodJob)
  # em vez de enviá-los durante a requisição.
  def send_devise_notification(notification, *)
    devise_mailer.send(notification, self, *).deliver_later
  end
end

# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  activated_at           :datetime
#  confirmation_sent_at   :datetime
#  confirmation_token     :string
#  confirmed_at           :datetime
#  current_sign_in_at     :datetime
#  current_sign_in_ip     :inet
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  last_sign_in_at        :datetime
#  last_sign_in_ip        :inet
#  name                   :string           not null
#  phone                  :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  sign_in_count          :integer          default(0), not null
#  unconfirmed_email      :string
#  user_type              :enum             default("operator"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  tenant_id              :bigint           not null
#
# Indexes
#
#  index_users_on_confirmation_token               (confirmation_token) UNIQUE
#  index_users_on_email                            (email) UNIQUE
#  index_users_on_reset_password_token             (reset_password_token) UNIQUE
#  index_users_on_tenant_id                        (tenant_id)
#  index_users_on_tenant_id_where_owner_user_type  (tenant_id) UNIQUE WHERE (user_type = 'owner'::user_type)
#
# Foreign Keys
#
#  fk_rails_...  (tenant_id => tenants.id)
#
