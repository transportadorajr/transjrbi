module Dashboard
  PerKmBase = Data.define(:gross, :net, :loaded_km, :excluded_count, :excluded_gross, :excluded_net) do
    def excluded?
      excluded_count.positive?
    end
  end
end
