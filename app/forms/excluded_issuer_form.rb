class ExcludedIssuerForm < BaseForm
  attribute :code, :integer

  validates :code, presence: true
  validate :code_must_be_available

  attr_accessor :tenant

  def excluded_issuer
    @excluded_issuer ||= tenant.excluded_issuers.new
  end

  def issuer_options
    @issuer_options ||= ExcludedIssuer.available_issuers(tenant).map { |name, code| [I18n.t('excluded_issuers.option', name:, code:), code] }
  end

  def submit
    excluded_issuer.update!(code:, name: issuer_name)
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
