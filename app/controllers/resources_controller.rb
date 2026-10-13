class ResourcesController < BaseController
  has_scope :by_name, as: :name
  has_scope :by_slug, as: :slug

  before_action :set_resource, only: %i[edit update destroy]

  def index
    authorize!(:read, Resource)

    @resources = apply_scopes(Resource.all).order(:name).page(params[:page])
  end

  def new
    authorize!(:create, Resource)

    @resource_form = ResourceForm.new
  end

  def edit
    authorize!(:update, @resource)

    @resource_form = ResourceForm.for_resource(@resource)
  end

  def create
    authorize!(:create, Resource)

    @resource_form = ResourceForm.new(resource_params)

    if @resource_form.save
      redirect_to resources_path, notice: t('.success')
    else
      flash.now[:alert] = @resource_form.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize!(:update, @resource)

    @resource_form = ResourceForm.for_resource(@resource)
    @resource_form.assign_attributes(resource_params)

    if @resource_form.save
      redirect_to resources_path, notice: t('.success')
    else
      flash.now[:alert] = @resource_form.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize!(:destroy, @resource)

    if @resource.destroy
      redirect_to resources_path, notice: t('.success')
    else
      redirect_to resources_path, alert: @resource.errors.full_messages.to_sentence
    end
  end

  private

  def set_resource
    @resource = Resource.find(params.expect(:id))
  end

  def resource_params
    params.expect(resource: %i[name slug writable])
  end
end
