class OwnFleetsController < BaseController
  def show
    authorize!(:read, :own_fleet)

    @own_fleet = OwnFleet.find_or_initialize_by(tenant: current_tenant)
  end

  def edit
    authorize!(:update, :own_fleet)

    @own_fleet_form = OwnFleetForm.for_tenant(current_tenant)
  end

  def update
    authorize!(:update, :own_fleet)

    @own_fleet_form = OwnFleetForm.for_tenant(current_tenant)
    @own_fleet_form.assign_attributes(own_fleet_params)

    if @own_fleet_form.save
      redirect_to own_fleet_path, notice: t('.success', count: @own_fleet_form.own_fleet.plates.size)
    else
      flash.now[:alert] = @own_fleet_form.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  private

  def own_fleet_params
    params.expect(own_fleet: %i[plates])
  end
end
