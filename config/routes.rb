PNet::Nanny::Application.routes.draw do

  match 'login' => 'admin#login', :as => :login
  match 'register' => 'worker#register'

  match 'mturk/review' => 'mturk#review', :as => :turkey
  match 'mturk/vote' => 'mturk#vote', :as => :vote

  match 'api/photo/submit' => 'photo_api#submit'

  match 'review/:action(/:id)' => 'review'
  match 'review' => 'review#index', :as => :review

  match 'eden/:action(/:id)' => 'admin'
  match 'eden' => 'admin#index'

  match 'test/:action(/:id)' => 'dummy'
  match 'bk(/:id)' => 'dummy#submit', :as => :bookmarklet
  
  match 'yum' => 'application#check_cookies'


  root :to => redirect('http://perceptualnet.com')
  # match '/*path' => redirect('http://perceptualnet.com')

end