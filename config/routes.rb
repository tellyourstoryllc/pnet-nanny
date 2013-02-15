PNet::Nanny::Application.routes.draw do

  match 'mturk/review' => 'mturk#review'
  match 'mturk/vote' => 'mturk#vote', :as => :vote

  match 'api/photo/submit' => 'photo_api#submit'

  match 'review/:action(/:id)' => 'review'
  match 'review' => 'review#index'

  match 'one_shot/:action(/:id)' => 'admin'
  match 'one_shot' => 'admin#index'

  match 'test/:action(/:id)' => 'dummy'
  
  match 'yum' => 'application#check_cookies'

  root :to => redirect('http://perceptualnet.com')
  # match '/*path' => redirect('http://perceptualnet.com')

end