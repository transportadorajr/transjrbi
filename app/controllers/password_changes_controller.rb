class PasswordChangesController < BaseController
  skip_before_action :require_password_change
  before_action :require_pending_password_change

  layout 'bare'

  def edit
    @password_change_form = PasswordChangeForm.new(user: current_user)
  end

  def update
    @password_change_form = PasswordChangeForm.new(user: current_user, **password_change_params)

    if @password_change_form.save
      bypass_sign_in(current_user)
      redirect_to root_path, notice: t('.success'), status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def require_pending_password_change
    redirect_to root_path unless current_user.password_change_required?
  end

  def password_change_params
    params.expect(password_change: %i[password password_confirmation]).to_h.symbolize_keys
  end
end
