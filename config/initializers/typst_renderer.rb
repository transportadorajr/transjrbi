require 'typst_pdf_generator'

ActionController::Renderers.add :typst do |template, options|
  resolved_template = template || "#{controller_path}/#{action_name}"

  typst_markup = render_to_string(
    template: resolved_template,
    layout: options[:layout] || false,
    formats: [:pdf],
    locals: { page_orientation: TypstPdfGenerator.orientation(options[:orientation]) },
  )

  pdf_data = TypstPdfGenerator.generate(typst_markup)
  filename = options[:filename] || I18n.t('typst.renderer.default_filename', time: Time.current.to_i)

  send_data pdf_data, type: 'application/pdf', disposition: 'inline', filename:
end
