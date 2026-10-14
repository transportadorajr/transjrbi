module Atua
  class ReprocessImportCommand
    class << self
      def call(import)
        new(import).call
      end
    end

    def initialize(import)
      @import = import
    end

    def call
      import.start!

      ProcessImportCommand.call(import)
    end

    private

    attr_reader :import
  end
end
