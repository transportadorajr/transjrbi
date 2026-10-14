RSpec.configure do |config|
  config.before(:each, :flipper) do |ex|
    flags = ex.metadata[:flipper]

    next Array(flags).each { Flipper.enable(it) } unless flags.is_a?(Hash)

    flags.each do |feature, actors|
      Array(actors).each { |actor| Flipper.enable_actor(feature, send(actor)) }
    end
  end
end
