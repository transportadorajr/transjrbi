class RouteDistanceImportForm < BaseForm
  EXTENSIONS = %w[.xlsx .xls].freeze

  attribute :file

  validates :file, presence: true
  validate :file_must_be_a_spreadsheet

  attr_accessor :tenant
  attr_reader :result

  def submit
    @result = RouteDistances::ImportCommand.call(tenant, file.path, extension)
  end

  private

  def extension
    File.extname(file.original_filename.to_s).downcase
  end

  def file_must_be_a_spreadsheet
    return if file.blank? || (file.respond_to?(:original_filename) && EXTENSIONS.include?(extension))

    errors.add(:file, :invalid_extension, extensions: EXTENSIONS.join(', '))
  end
end
