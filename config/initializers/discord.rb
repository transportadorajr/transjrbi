Rails.application.config.after_initialize do
  Rails.error.subscribe(Discord::ErrorSubscriber.new) if Rails.env.production? && Discord.configured?
end
