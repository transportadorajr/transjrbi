class CommissionRulesController < BaseController
  has_scope :by_name, as: :name
  has_scope :by_customer_group, as: :customer_group_id
  has_scope :by_status, as: :status

  before_action :set_commission_rule, only: %i[show edit update destroy]

  def index
    authorize!(:read, :commission_rules)

    commission_rules = current_tenant.commission_rules
    counted_commission_rules = apply_scopes(commission_rules, params.except(:status))

    @commission_rules = apply_scopes(commission_rules).preload(:customer_group)
      .joins(:customer_group).order(CustomerGroup.arel_table[:name], :name, :id).page(params[:page])
    @customer_groups = current_tenant.customer_groups.where(id: current_tenant.commission_rules.select(:customer_group_id)).order(:name)
    @total_count = counted_commission_rules.count
    @active_count = counted_commission_rules.activated.count
    @deactivated_count = counted_commission_rules.not_activated.count
  end

  def show
    authorize!(:read, :commission_rules)

    @expenses_count = @commission_rule.freight_expenses.count
    @expenses_total = Money.from_cents(@commission_rule.freight_expenses.sum(:amount_cents))
  end

  def new
    authorize!(:create, :commission_rules)

    @commission_rule_form = CommissionRuleForm.new(tenant: current_tenant)
  end

  def edit
    authorize!(:update, :commission_rules)

    @commission_rule_form = CommissionRuleForm.for_commission_rule(@commission_rule)
  end

  def create
    authorize!(:create, :commission_rules)

    @commission_rule_form = CommissionRuleForm.new(tenant: current_tenant, **commission_rule_params)

    if @commission_rule_form.save
      redirect_to commission_rule_path(@commission_rule_form.commission_rule), notice: t('.success')
    else
      flash.now[:alert] = @commission_rule_form.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize!(:update, :commission_rules)

    @commission_rule_form = CommissionRuleForm.for_commission_rule(@commission_rule)
    @commission_rule_form.assign_attributes(commission_rule_params)

    if @commission_rule_form.save
      redirect_to commission_rule_path(@commission_rule), notice: t('.success')
    else
      flash.now[:alert] = @commission_rule_form.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize!(:destroy, :commission_rules)

    if @commission_rule.destroy
      redirect_to commission_rules_path, notice: t('.success')
    else
      redirect_to commission_rules_path, alert: @commission_rule.errors.full_messages.to_sentence
    end
  end

  private

  def set_commission_rule
    @commission_rule = current_tenant.commission_rules.find(params.expect(:id))
  end

  def commission_rule_params
    params.expect(commission_rule: %i[customer_group_id name destination_type base_type percentage cities recipient_terms active])
  end
end
