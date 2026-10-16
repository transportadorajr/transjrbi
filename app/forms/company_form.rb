class CompanyForm < BaseForm
  attribute :name, :string
  attribute :trade_name, :string
  attribute :legal_id, :string
  attribute :atua_url, :string
  attribute :atua_device_token, :string
  attribute :atua_device_hash, :string

  before_validation :normalize_fields

  validates :name, :trade_name, :legal_id, presence: true
  validates :atua_url, format: { with: URI::RFC2396_PARSER.make_regexp(%w[http https]) }, allow_blank: true
  validate :legal_id_must_not_be_duplicated

  attr_accessor :tenant

  delegate :id, :persisted?, to: :tenant

  class << self
    def for_tenant(tenant)
      new(tenant:, name: tenant.name, trade_name: tenant.trade_name, legal_id: tenant.legal_id, atua_url: tenant.atua_url)
    end
  end

  def submit
    tenant.update!(name:, trade_name:, legal_id:, atua_url: atua_url.presence, **device_attributes)
  end

  private

  def normalize_fields
    self.name = name.to_s.squish
    self.trade_name = trade_name.to_s.squish
    self.legal_id = legal_id.to_s.strip
    self.atua_url = atua_url.to_s.strip.delete_suffix('/')
    self.atua_device_token = atua_device_token.to_s.strip
    self.atua_device_hash = atua_device_hash.to_s.strip
  end

  def device_attributes
    { atua_device_token:, atua_device_hash: }.compact_blank
  end

  def legal_id_must_not_be_duplicated
    return if legal_id.blank? || !Tenant.where(legal_id:).where.not(id: tenant.id).exists?

    errors.add(:legal_id, :taken)
  end
end
