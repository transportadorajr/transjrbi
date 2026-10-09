FactoryBot.define do
  factory :user do
    tenant
    name { 'João Silva' }
    sequence(:email) { |n| "usuario#{n}@transjrbi.com.br" }
    password { 'Senha123!' }
    password_confirmation { 'Senha123!' }
    user_type { 'operator' }
    activated_at { Time.current }
    confirmed_at { Time.current }
  end
end
