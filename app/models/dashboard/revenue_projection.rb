module Dashboard
  class RevenueProjection
    FEATURE = :revenue_projection

    class << self
      def enabled?(tenant)
        Flipper.enabled?(FEATURE, tenant)
      end
    end
  end
end
