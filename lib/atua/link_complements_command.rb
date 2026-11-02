module Atua
  class LinkComplementsCommand
    SQL = <<~SQL.squish.freeze
      UPDATE atua_transport_documents
      SET complemented_transport_document_id = targets.original_id, updated_at = NOW()
      FROM (
        SELECT complements.id,
               CASE WHEN complements.issue_kind = :value_complement THEN originals.id END AS original_id
        FROM atua_transport_documents complements
        LEFT JOIN LATERAL (
          SELECT candidates.id
          FROM atua_transport_documents candidates
          WHERE candidates.tenant_id = complements.tenant_id
            AND candidates.number = complements.complemented_number
            AND candidates.series IS NOT DISTINCT FROM complements.series
            AND candidates.branch_name IS NOT DISTINCT FROM complements.branch_name
            AND candidates.issue_kind IS DISTINCT FROM :value_complement
            AND candidates.removed_from_atua_at IS NULL
            AND candidates.canceled_at IS NULL
          ORDER BY candidates.issued_at DESC NULLS LAST, candidates.code DESC
          LIMIT 1
        ) originals ON TRUE
        WHERE complements.tenant_id = :tenant_id
          AND (complements.issue_kind = :value_complement OR complements.complemented_transport_document_id IS NOT NULL)
      ) targets
      WHERE atua_transport_documents.id = targets.id
        AND atua_transport_documents.complemented_transport_document_id IS DISTINCT FROM targets.original_id
    SQL

    class << self
      def call(tenant)
        new(tenant).call
      end
    end

    def initialize(tenant)
      @tenant = tenant
    end

    def call
      TransportDocument.connection.exec_update(TransportDocument.sanitize_sql_array([SQL, binds]))
    end

    private

    attr_reader :tenant

    def binds
      { tenant_id: tenant.id, value_complement: TransportDocument::VALUE_COMPLEMENT }
    end
  end
end
