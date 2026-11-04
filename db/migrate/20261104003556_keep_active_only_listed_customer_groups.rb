class KeepActiveOnlyListedCustomerGroups < ActiveRecord::Migration[8.1]
  ACTIVE_GROUPS = [
    'ACB', 'ALAMEDA', 'ARAUCO', 'ARCELOR', 'BIGOLIN', 'COAGRU', 'COMERCIAL DESTRO LTDA', 'CONSOLATA', 'INDEMIL', 'MOVISTAR',
    'MULTIAMIDOS', 'NUTRIAMIDOS DERIVADOS DA MANDIOCA LTDA', 'PANORAMA', 'RÉGIO', 'RIO AZUL', 'RUDOLF', 'SOORO', 'TERRAFEC', 'TRADIÇÃO',
    'UNIDAS', 'USIMINAS', 'USINAS SIDERURGICAS DE MINAS GERAIS S A', 'VIRGINIA'
  ].freeze

  def up
    Tenant.find_each { |tenant| CustomerGroups::KeepActiveCommand.call(tenant, ACTIVE_GROUPS) }
  end

  def down; end
end
