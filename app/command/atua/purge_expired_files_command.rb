module Atua
  class PurgeExpiredFilesCommand
    class << self
      delegate :call, to: :new
    end

    def call
      Import.with_expired_file.preload(:file_attachment).find_each.count do |import|
        import.file.purge
      end
    end
  end
end
