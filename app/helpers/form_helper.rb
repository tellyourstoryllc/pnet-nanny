module FormHelper
  
  def yes_no_radio_tag(name, value)
    value = false if value.nil?
    radio_button_tag(name, 1, value) + 'Yes ' + radio_button_tag(name, 0, !value) + 'No'
  end
  
end