FactoryBot.define do
  factory :admin_session, class: 'Admin::Session' do
    user factory: :admin_user
    last_active_at { Time.current }
  end
end
