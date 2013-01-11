class User < Peanut::ActivePeanut::Base
  def login(arg)
    true
  end
  
  def logout
    true
  end    
end