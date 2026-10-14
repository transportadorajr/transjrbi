module Admin
  class SessionsController < ApplicationController
    include Admin::Authentication

    layout 'bare'

    def new
      @login_form = Admin::LoginForm.new
    end

    def create
      @login_form = Admin::LoginForm.new(login_params)

      if @login_form.save
        sign_in_admin_user(@login_form.user)
        redirect_to admin_root_path, notice: t('.success')
      else
        flash.now[:alert] = @login_form.errors.full_messages.to_sentence
        render :new, status: :unprocessable_content
      end
    end

    def destroy
      sign_out_admin_user
      redirect_to admin_login_path, notice: t('.success'), status: :see_other
    end

    private

    def login_params
      params.expect(admin_login: %i[email password])
    end
  end
end
