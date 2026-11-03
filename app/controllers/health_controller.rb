class HealthController < Rails::HealthController
  DRAIN_FILE = Rails.root.join('tmp/drain')

  def show
    return head(:service_unavailable) if DRAIN_FILE.exist?

    super
  end
end
