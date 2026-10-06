class User < ApplicationRecord
  # Módulos do Devise em uso.
  # Disponíveis para o futuro: :lockable, :timeoutable, :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :trackable

  private

  # Envia os e-mails do Devise em segundo plano (fila do GoodJob)
  # em vez de enviá-los durante a requisição.
  def send_devise_notification(notification, *args)
    devise_mailer.send(notification, self, *args).deliver_later
  end
end
