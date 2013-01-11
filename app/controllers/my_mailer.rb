require 'actionmailer'
class MyMailer < ActionMailer::Base
  
  helper :application
  MyMailer.template_root = File.dirname(__FILE__) + '/../views'
  
  def default_sender
    default_email = Settings.get('support_email') || 'mod@perceptualnet.com'
    @default_sender = Settings.get('default_sender') || "Megamod <#{default_email}>"
  end

  def perform_delivery_test(mail)
    
  end
    
  # Our custom delivery method checks the blacklist status before sending each email.
  def perform_delivery_live(mail)
    mail.destinations.each do |dest|
      email_domain = Settings.get('mail_domain') || 'perceptualnet.com'
      # using authsmtp for everything except mail to ourselves.      
      smtp_settings = ActionMailer::Base.smtp_settings
      unless dest.include?(email_domain) || dest.include?("txt.att.net")
	      smtp_settings[:address] = 'smtp.sendgrid.net'
        smtp_settings[:port] = 25
        smtp_settings[:authentication] = :plain
        smtp_settings[:user_name] = 'jimyoung@gmail.com'
        smtp_settings[:password] = 'mtndew'
        smtp_settings[:domain] = email_domain
      end

      mail.ready_to_send

      Net::SMTP.start(smtp_settings[:address], smtp_settings[:port], smtp_settings[:domain], 
        smtp_settings[:user_name], smtp_settings[:password], smtp_settings[:authentication]) do |smtp|
        smtp.sendmail(mail.encoded, mail.from, dest)
      end
    end if mail.destinations
  end
  
end
