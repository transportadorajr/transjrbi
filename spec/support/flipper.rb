RSpec.configure do |config|
  config.before(:each, :flipper) do |ex|
    flags = Array(ex.metadata[:flipper])
    flags.each { Flipper.enable(it) }
  end
end
