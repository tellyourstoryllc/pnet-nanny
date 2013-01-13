class Markup < Builder::XmlMarkup
  alias_method :-, :text!
  alias_method :<, :<<

  def append_with_leading_space(el)
    self << ' '
    self << el
  end

  alias_method :/, :append_with_leading_space
  
end