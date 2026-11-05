module Atua
  class DiscardManifestsBeforeCutoffCommand
    ACCESS_KEY = /\b\d{44}\b/
    TRANSPORT_DOCUMENT_MODEL = '57'.freeze

    class << self
      def call(tenant, cutoff = PurgeMovementsBeforeCommand::CUTOFF)
        new(tenant, cutoff).call
      end
    end

    def initialize(tenant, cutoff)
      @tenant = tenant
      @cutoff = cutoff.to_date
    end

    def call
      codes = candidates.select { |manifest| issued_before_cutoff?(manifest) }.map(&:code)
      return 0 if codes.empty?

      discarded = discard(codes)
      EmptyLegs::ScheduleCalculationCommand.call(tenant.id)

      discarded
    end

    private

    attr_reader :tenant, :cutoff

    def candidates
      linked = tenant.atua_manifest_documents.active.joins(:transport_document).select(:manifest_code)

      tenant.atua_manifests.active.where(code: tenant.atua_manifest_documents.active.select(:manifest_code))
        .where.not(code: linked).preload(:documents)
    end

    def issued_before_cutoff?(manifest)
      months = issued_months(manifest.notes)

      manifest.documents.select(&:active?).all? do |document|
        month = months[[document.transport_document_number.to_i, document.transport_document_series.to_i]]
        month.present? && month < cutoff
      end
    end

    def issued_months(notes)
      notes.to_s.scan(ACCESS_KEY).select { |key| key[20, 2] == TRANSPORT_DOCUMENT_MODEL }.to_h do |key|
        [[key[25, 9].to_i, key[22, 3].to_i], Date.new(2000 + key[2, 2].to_i, key[4, 2].to_i, 1)]
      end
    end

    def discard(codes)
      now = Time.current

      Manifest.transaction do
        tenant.atua_manifest_documents.active.where(manifest_code: codes).update_all(removed_from_atua_at: now, updated_at: now)
        tenant.atua_manifests.where(code: codes).update_all(removed_from_atua_at: now, updated_at: now)
      end
    end
  end
end
