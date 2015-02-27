sendgrid_config = YAML.load_file("#{Rails.root}/config/mail.yml")[Rails.env]
host_config = YAML.load_file("#{Rails.root}/config/host.yml")[Rails.env]

if sendgrid_config and sendgrid_config['username'] and sendgrid_config['password']
  PNet::Nanny::Application.config.action_mailer.smtp_settings = {
    :address              => 'smtp.sendgrid.net',
    :port                 => 587,
    :domain               => sendgrid_config['domain'],
    :user_name            => sendgrid_config['username'],
    :password             => sendgrid_config['password'],
    :authentication       => 'plain',
    :enable_starttls_auto => true
  }

  PNet::Nanny::Application.config.action_mailer.default_url_options = {host: host_config['host']}
end
