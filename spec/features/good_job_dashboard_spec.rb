require 'rails_helper'

describe 'GoodJob dashboard on the app host' do
  let!(:user) { create(:user) }

  before { login_as(user, scope: :user) }

  scenario 'is not reachable by an app user' do
    visit '/good_job'

    expect(page.status_code).to eq(404)
  end

  scenario 'is not linked from the app navigation' do
    visit root_path

    expect(page).to have_text(user.email)
    expect(page).to have_no_link(href: '/good_job')
  end
end
