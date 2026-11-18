class ExportShortcutsController < BaseController
  include Activation

  has_scope :by_name, as: :name
  has_scope :by_status, as: :status

  before_action :require_export_summary
  before_action :set_export_shortcut, only: %i[show edit update destroy activate deactivate]

  def index
    authorize!(:read, :export_shortcuts)

    export_shortcuts = current_tenant.export_shortcuts
    counted_export_shortcuts = apply_scopes(export_shortcuts, params.except(:status))

    @export_shortcuts = listing_page(apply_sort(apply_scopes(export_shortcuts).preload(:customer_group), :position, :name, :id))
    @total_count = counted_export_shortcuts.count
    @active_count = counted_export_shortcuts.activated.count
    @deactivated_count = counted_export_shortcuts.not_activated.count

    respond_with_listing(orientation: :landscape, xlsx: @export_shortcuts)
  end

  def show
    authorize!(:read, :export_shortcuts)
  end

  def new
    authorize!(:create, :export_shortcuts)

    @export_shortcut_form = ExportShortcutForm.new(tenant: current_tenant)
  end

  def edit
    authorize!(:update, :export_shortcuts)

    @export_shortcut_form = ExportShortcutForm.for_export_shortcut(@export_shortcut)
  end

  def create
    authorize!(:create, :export_shortcuts)

    @export_shortcut_form = ExportShortcutForm.new(tenant: current_tenant, **export_shortcut_params)

    if @export_shortcut_form.save
      redirect_to export_shortcut_path(@export_shortcut_form.export_shortcut), notice: t('.success')
    else
      flash.now[:alert] = @export_shortcut_form.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize!(:update, :export_shortcuts)

    @export_shortcut_form = ExportShortcutForm.for_export_shortcut(@export_shortcut)
    @export_shortcut_form.assign_attributes(export_shortcut_params)

    if @export_shortcut_form.save
      redirect_to export_shortcut_path(@export_shortcut), notice: t('.success')
    else
      flash.now[:alert] = @export_shortcut_form.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize!(:destroy, :export_shortcuts)

    if @export_shortcut.destroy
      redirect_to export_shortcuts_path, notice: t('.success')
    else
      redirect_to export_shortcuts_path, alert: @export_shortcut.errors.full_messages.to_sentence
    end
  end

  private

  def require_export_summary
    raise ActionController::RoutingError, 'Not Found' unless ExportPlant.enabled?(current_tenant)
  end

  def activation_form
    ExportShortcutForm.for_export_shortcut(@export_shortcut)
  end

  def set_export_shortcut
    @export_shortcut = current_tenant.export_shortcuts.find(params.expect(:id))
  end

  def export_shortcut_params
    params.expect(export_shortcut: [:name, :customer_group_id, :position, :active, { export_plant_ids: [], countries: [] }])
  end
end
