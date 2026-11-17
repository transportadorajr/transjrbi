class ExcludedIssuerForm < BaseForm
  attribute :code, :integer
  attribute :active, :boolean, default: true

  validates :code, presence: true
  validate :code_must_be_available, unless: :persisted?

  attr_accessor :tenant
  attr_writer :excluded_issuer

  delegate :persisted?, to: :excluded_issuer

  class << self
    def for_excluded_issuer(excluded_issuer)
      form = new(code: excluded_issuer.code, active: excluded_issuer.active?, tenant: excluded_issuer.tenant)
      form.excluded_issuer = excluded_issuer
      form
    end
  end

  def excluded_issuer
    @excluded_issuer ||= tenant.excluded_issuers.new
  end

  def issuer_options
    @issuer_options ||= ExcludedIssuer.available_issuers(tenant).map { |name, code| [I18n.t('excluded_issuers.option', name:, code:), code] }
  end

  def submit
    return excluded_issuer.update!(active:) if persisted?

    excluded_issuer.update!(code:, name: issuer_name, active:)
  end

  private

  def issuer_name
    ExcludedIssuer.available_issuers(tenant).to_h(&:reverse).fetch(code)
  end

  def code_must_be_available
    return if code.blank?

    if tenant.excluded_issuers.exists?(code:)
      errors.add(:code, :taken)
    elsif ExcludedIssuer.available_issuers(tenant).none? { |_name, issuer_code| issuer_code == code }
      errors.add(:code, :inclusion)
    end
  end
end
