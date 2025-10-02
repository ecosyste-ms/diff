module ApplicationHelper
  def meta_title
    [@meta_title, 'Ecosyste.ms: Diff'].compact.join(' | ')
  end

  def meta_description
    @meta_description || app_description
  end

  def app_name
    "Diff"
  end

  def app_description
    "An open API service to generate diffs between package releases for many open source software ecosystems."
  end

  def bootstrap_icon(symbol, options = {})
    return "" if symbol.nil?
    icon = BootstrapIcons::BootstrapIcon.new(symbol, options)
    content_tag(:svg, icon.path.html_safe, icon.options)
  end
end
