class UsersController < BaseController
  has_scope :by_name, as: :name
  has_scope :by_status, as: :status

  before_action :set_user, only: %i[show edit update destroy activate]
  before_action :set_resources, only: %i[new create edit update]

  def index
    authorize!(:read, User)

    users = current_tenant.users.accessible_by(current_ability)
    counted_users = apply_scopes(users, params.except(:status))

    @users = apply_scopes(users).order(:name).page(params[:page])
    @total_count = counted_users.count
    @active_count = counted_users.activated.count
    @deactivated_count = counted_users.not_activated.count
  end

  def show
    authorize!(:read, @user)

    @accesses = @user.accesses.preload(:resource).sort_by { |access| access.resource.translated_name }
  end

  def new
    authorize!(:create, User)

    @user_form = UserForm.new(editor: current_user)
  end

  def edit
    authorize!(:update, @user)

    @user_form = UserForm.for_user(@user, editor: current_user)
  end

  def create
    authorize!(:create, User)

    @user_form = UserForm.new(editor: current_user, **user_params)

    if @user_form.save
      redirect_to users_path, notice: t('.success')
    else
      flash.now[:alert] = @user_form.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize!(:update, @user)

    @user_form = UserForm.for_user(@user, editor: current_user)
    @user_form.assign_attributes(user_edit_params)

    if @user_form.save
      redirect_to user_path(@user), notice: t('.success')
    else
      flash.now[:alert] = @user_form.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize!(:deactivate, @user)

    @user.update!(activated: false)

    redirect_to users_path(**listing_params), notice: t('.success')
  end

  def activate
    authorize!(:deactivate, @user)

    @user.update!(activated: true)

    redirect_to users_path(**listing_params), notice: t('.success')
  end

  private

  def listing_params
    params.slice(:name, :status, :page).permit(:name, :status, :page).to_h.symbolize_keys
  end

  def set_user
    @user = current_tenant.users.find(params.expect(:id))
  end

  def set_resources
    @resources = Resource.order(:name)
  end

  def user_params
    params.expect(user: [:name, :email, :phone, :user_type, { access_attributes: [Access::PERMITTED_ATTRIBUTES] }])
  end

  def user_edit_params
    params.expect(user: [:name, :phone, :user_type, { access_attributes: [Access::PERMITTED_ATTRIBUTES] }])
  end
end
