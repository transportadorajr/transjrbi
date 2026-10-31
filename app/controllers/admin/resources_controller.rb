module Admin
  class ResourcesController < BaseController
    has_scope :by_name, as: :name
    has_scope :by_slug, as: :slug

    before_action :set_resource, only: %i[edit update destroy]

    def index
      @resources = apply_sort(apply_scopes(Resource.all), :name, :id).page(params[:page])
    end

    def new
      @resource_form = Admin::ResourceForm.new
    end

    def edit
      @resource_form = Admin::ResourceForm.for_resource(@resource)
    end

    def create
      @resource_form = Admin::ResourceForm.new(resource_params)

      if @resource_form.save
        redirect_to admin_resources_path, notice: t('.success')
      else
        flash.now[:alert] = @resource_form.errors.full_messages.to_sentence
        render :new, status: :unprocessable_content
      end
    end

    def update
      @resource_form = Admin::ResourceForm.for_resource(@resource)
      @resource_form.assign_attributes(resource_params)

      if @resource_form.save
        redirect_to admin_resources_path, notice: t('.success')
      else
        flash.now[:alert] = @resource_form.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      if @resource.destroy
        redirect_to admin_resources_path, notice: t('.success')
      else
        redirect_to admin_resources_path, alert: @resource.errors.full_messages.to_sentence
      end
    end

    private

    def set_resource
      @resource = Resource.find(params.expect(:id))
    end

    def resource_params
      params.expect(admin_resource: %i[name slug writable])
    end
  end
end
