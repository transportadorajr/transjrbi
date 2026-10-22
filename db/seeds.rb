# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

if ENV['ADMIN_USER_EMAIL'].present? && ENV['ADMIN_USER_PASSWORD'].present?
  Admin::User.find_or_create_by!(email: ENV['ADMIN_USER_EMAIL'].strip.downcase) do |admin_user|
    admin_user.name = ENV.fetch('ADMIN_USER_NAME', 'Administrador')
    admin_user.password = ENV.fetch('ADMIN_USER_PASSWORD')
  end
end

Tenant.find_each { |tenant| EmptyLegs::CalculateAllCommand.call(tenant) } if Tomtom.configured?

Tenant.find_each do |tenant|
  CustomerGroups::BackfillCommand.call(tenant)
  FreightExpenses::CalculateTarpLiningCommand.call(tenant)
  TruckGroups::BackfillCommand.call(tenant)
end
