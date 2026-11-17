module SignatureHelpers
  SAMPLE_STROKES = [Array.new(12) { |index| [(0.1 + (index * 0.06)).round(3), (0.3 + (index * 0.03)).round(3)] }].freeze

  def signature_strokes
    SAMPLE_STROKES.to_json
  end

  def draw_signature(canvas_id)
    page.execute_script("document.getElementById('#{canvas_id}').scrollIntoView({ block: 'center' })")
    left, top, width, height = page.evaluate_script(
      "(() => { const r = document.getElementById('#{canvas_id}').getBoundingClientRect(); return [r.left, r.top, r.width, r.height]; })()",
    )
    mouse = page.driver.browser.mouse

    mouse.move(x: left + (width * 0.1), y: top + (height * 0.5))
    mouse.down
    12.times { |step| mouse.move(x: left + (width * (0.1 + (step * 0.06))), y: top + (height * (0.3 + (step * 0.03)))) }
    mouse.up
  end
end

RSpec.configure do |config|
  config.include SignatureHelpers
end
