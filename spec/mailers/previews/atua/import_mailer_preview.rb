module Atua
  class ImportMailerPreview < ActionMailer::Preview
    def repeated_failures
      tenant = Tenant.new(id: 1, name: 'Transportadora JR Ltda', trade_name: 'TransJR', legal_id: '12.345.678/0001-90')
      import = Atua::Import.new(
        id: 1, tenant:, report_type: :transport_documents, status_type: :failed, error_type: :authentication,
        error_message: 'A Atua recusou o login, a resposta ainda contém o formulário de login.'
      )

      Atua::ImportMailer.repeated_failures(import)
    end
  end
end
