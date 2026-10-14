FactoryBot.define do
  factory :admin_user, class: 'Admin::User' do
    name { 'Marina Suporte' }
    sequence(:email) { |n| "admin#{n}@transjrbi.com.br" }
    password { 'Senha123!' }
  end
end
