module Activation
  extend ActiveSupport::Concern

  def activate
    change_activation(true)
  end

  def deactivate
    change_activation(false)
  end

  private

  def change_activation(active)
    authorize_activation!

    form = activation_form

    if form.save_activation(active)
      redirect_back_or_to url_for(action: :index), notice: t("shared.activation.#{active ? :activated : :deactivated}")
    else
      redirect_back_or_to url_for(action: :index), alert: form.errors.full_messages.to_sentence
    end
  end

  def authorize_activation!
    authorize!(:update, controller_name.to_sym)
  end
end
