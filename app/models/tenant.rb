class Tenant < ApplicationRecord
  has_many :users, dependent: :restrict_with_error
  has_many :accesses, dependent: :restrict_with_error
  has_many :atua_imports, class_name: 'Atua::Import', dependent: :destroy
  has_many :atua_transport_documents, class_name: 'Atua::TransportDocument', dependent: :delete_all
  has_many :atua_transport_document_manifests, class_name: 'Atua::TransportDocumentManifest', dependent: :delete_all
  has_many :atua_manifests, class_name: 'Atua::Manifest', dependent: :delete_all
  has_many :atua_manifest_documents, class_name: 'Atua::ManifestDocument', dependent: :delete_all
  has_many :atua_expenses, class_name: 'Atua::Expense', dependent: :delete_all
  has_many :atua_customers, class_name: 'Atua::Customer', dependent: :delete_all
  has_many :atua_vehicles, class_name: 'Atua::Vehicle', dependent: :delete_all

  validates :name, :legal_id, :trade_name, presence: true
  validates :legal_id, uniqueness: true
  validates :atua_url, format: { with: URI::RFC2396_PARSER.make_regexp(%w[http https]) }, allow_blank: true

  encrypts :atua_device_token
  encrypts :atua_device_hash
end

# == Schema Information
#
# Table name: tenants
#
#  id                :bigint           not null, primary key
#  atua_device_hash  :text
#  atua_device_token :text
#  atua_url          :string
#  name              :string           not null
#  trade_name        :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  legal_id          :string           not null
#
# Indexes
#
#  index_tenants_on_legal_id  (legal_id) UNIQUE
#
