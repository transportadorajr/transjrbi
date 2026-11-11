class HolidaysController < BaseController
  has_scope :by_year, as: :year, default: -> { Date.current.year }
  has_scope :by_name, as: :name
  has_scope :by_scope_type, as: :scope_type

  before_action :set_holiday, only: %i[edit update destroy]

  def index
    authorize!(:read, :holidays)

    @holidays = listing_page(apply_sort(apply_scopes(current_tenant.holidays), :date, :id))
    @years = holiday_years
  end

  def new
    authorize!(:create, :holidays)

    @holiday_form = HolidayForm.new(tenant: current_tenant)
  end

  def edit
    authorize!(:update, :holidays)

    @holiday_form = HolidayForm.for_holiday(@holiday)
  end

  def create
    authorize!(:create, :holidays)

    @holiday_form = HolidayForm.new(tenant: current_tenant, **holiday_params)

    if @holiday_form.save
      redirect_to holidays_path(year: @holiday_form.date.year), notice: t('.success')
    else
      flash.now[:alert] = @holiday_form.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize!(:update, :holidays)

    @holiday_form = HolidayForm.for_holiday(@holiday)
    @holiday_form.assign_attributes(holiday_params)

    if @holiday_form.save
      redirect_to holidays_path(year: @holiday.date.year), notice: t('.success')
    else
      flash.now[:alert] = @holiday_form.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize!(:destroy, :holidays)

    @holiday.destroy!
    redirect_to holidays_path(year: @holiday.date.year), notice: t('.success')
  end

  private

  def set_holiday
    @holiday = current_tenant.holidays.find(params.expect(:id))
  end

  def holiday_params
    params.expect(holiday: %i[date name scope_type kind_type])
  end

  def holiday_years
    years = current_tenant.holidays.distinct.pluck(Arel.sql('EXTRACT(YEAR FROM date)::integer'))

    (years + [Date.current.year]).uniq.sort.reverse
  end
end
