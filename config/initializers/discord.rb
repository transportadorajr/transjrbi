Rails.application.config.after_initialize do
  Rails.error.subscribe(Discord::ErrorSubscriber.new) if Discord.enabled?
end
