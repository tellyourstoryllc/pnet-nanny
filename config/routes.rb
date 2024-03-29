PNet::Nanny::Application.routes.draw do

  match 'login' => 'admin#login', :as => :login
  match 'register' => 'worker#register'
  match 'edit' => 'worker#edit'
  match 'update' => 'worker#update'
  match 'forgot_password' => 'worker#forgot_password', as: :forgot_password
  match 'password/reset' => 'worker#send_reset_email', as: :send_reset_email
  match 'password/reset/:token' => 'worker#reset_password', as: :reset_password

  match 'mturk/review' => 'mturk#review', :as => :turkey
  match 'mturk/vote' => 'mturk#vote', :as => :vote

  match 'api/video/submit' => 'video_api#submit'
  match 'api/video/delete' => 'video_api#delete'
  match 'api/photo/submit' => 'photo_api#submit'
  match 'api/photo/delete' => 'photo_api#delete'

  match 'review/:action(/:id)' => 'review'
  match 'review' => 'review#index', :as => :review

  match 'videos' => 'videos#index', :as => :pending_videos_queue
  match 'videos/held' => 'videos#held', :as => :held_videos_queue
  match 'videos(/:action(/:id))' => 'videos'
  match 'video_testing(/:action)' => 'video_testing'

  match 'eden/:action(/:id)' => 'admin'
  match 'eden' => 'admin#index'

  match 'test/:action(/:id)' => 'dummy'
  match 'bk(/:id)' => 'dummy#submit', :as => :bookmarklet
  
  match 'yum' => 'application#check_cookies'


  #root :to => redirect('http://perceptualnet.com')
  root to: 'videos#index'
  # match '/*path' => redirect('http://perceptualnet.com')

end
