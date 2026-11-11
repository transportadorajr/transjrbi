class AccountPasswordsController < BaseController
  def edit
    @account_password_form = AccountPasswordForm.new(user: current_user)
  end

  def update
    @account_password_form = AccountPasswordForm.new(user: current_user, **account_password_params)

    if @account_password_form.save
      bypass_sign_in(current_user)
      remember_me(current_user)
      redirect_to user_path(current_user), notice: t('.success'), status: :see_other
    else
      flash.now[:alert] = @account_password_form.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  private

  def account_password_params
    params.expect(account_password: %i[current_password password password_confirmation]).to_h.symbolize_keys
  end
end
