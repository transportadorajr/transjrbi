module DistanceAdjustments
  class ApplyCommand
    class << self
      def call(adjustment)
        new(adjustment).call
      end
    end

    def initialize(adjustment)
      @adjustment = adjustment
      @applied_at = Time.current
    end

    def call
      documents_count = documents.count
      return 0 if documents_count.zero?

      changed = adjust_original_documents + adjust_already_adjusted_documents
      adjustment.update!(applied_at:) if changed.positive? || !adjustment.applied?

      documents_count
    end

    private

    attr_reader :adjustment, :applied_at

    def documents
      adjustment.transport_documents
    end

    def adjust_original_documents
      documents.where(distance_adjusted_at: nil).update_all(
        [
          'original_distance_km = distance_km, distance_km = ?, distance_adjusted_at = ?, updated_at = ?',
          adjustment.distance_km, applied_at, applied_at
        ],
      )
    end

    def adjust_already_adjusted_documents
      documents.where.not(distance_adjusted_at: nil).where('distance_km IS DISTINCT FROM ?', adjustment.distance_km)
        .update_all(distance_km: adjustment.distance_km, distance_adjusted_at: applied_at, updated_at: applied_at)
    end
  end
end
