class Resource < ApplicationRecord
  SLUG_FORMAT = /\A[a-z][a-z0-9_]*\z/

  scope :by_name, ->(name) { where(arel_table[:name].matches("%#{sanitize_sql_like(name)}%")) }
  scope :by_slug, ->(slug) { where(arel_table[:slug].matches("%#{sanitize_sql_like(slug)}%")) }

  def translated_name
    translation_key = "resource_names.#{slug}"

    return I18n.t(translation_key) if I18n.exists?(translation_key)

    name
  end
end

# == Schema Information
#
# Table name: resources
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  slug       :string           not null
#  writable   :boolean          default(TRUE), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_resources_on_slug  (slug) UNIQUE
#
