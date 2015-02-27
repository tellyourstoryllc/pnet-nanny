class WorkerMailer < BaseMailer
  def password_reset(worker, token)
    @url = reset_password_url(token)
    mail(to: worker.email, subject: 'Password Reset Instructions')
  end
end
