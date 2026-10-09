module Users
  class ConfirmationsController < Devise::ConfirmationsController
    def show
      @user_confirmation_form = UserConfirmationForm.new(confirmation_token: params[:confirmation_token])

      return super unless @user_confirmation_form.pending?

      set_minimum_password_length
    end

    def update
      @user_confirmation_form = UserConfirmationForm.new(user_confirmation_params)

      if @user_confirmation_form.save
        sign_in(@user_confirmation_form.user)
        redirect_to root_path, notice: t('.success')
      else
        set_minimum_password_length
        render :show, status: :unprocessable_content
      end
    end

    private

    def user_confirmation_params
      params.expect(user_confirmation: %i[confirmation_token password password_confirmation])
    end
  end
end
