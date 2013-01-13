class Markup < Builder::XmlMarkup
  alias_method :-, :text!
  alias_method :/, :<<
end