require 'open3'

class TypstPdfGenerator
  ORIENTATIONS = %i[portrait landscape].freeze

  class << self
    def generate(typst_markup)
      binary_path = Pathname.new(ENV.fetch('TYPST_PDF_BINARY') { Rails.root.join('bin', 'rust_typst_pdf').to_s })

      raise I18n.t('typst.pdf_generator.missing_binary', path: binary_path.to_s) unless binary_path.executable?

      pdf_data, error, status = Open3.capture3(
        binary_path.to_s,
        stdin_data: typst_markup,
        binmode: true,
      )

      raise I18n.t('typst.pdf_generator.compilation_error', error:) unless status.success?

      pdf_data
    end

    def orientation(value)
      orientation = (value || :portrait).to_sym
      return orientation if ORIENTATIONS.include?(orientation)

      raise ArgumentError, I18n.t('typst.pdf_generator.invalid_orientation', orientation:, allowed: ORIENTATIONS.join(', '))
    end
  end
end
