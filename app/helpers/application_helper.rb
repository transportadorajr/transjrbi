module ApplicationHelper
  def icon(name, options = {})
    tag.i(**options, class: [ "bi", "bi-#{name}", options[:class] ], aria: { hidden: true })
  end
end
