PNet::Nanny::Application.routes.draw do

  match 'mturk/review' => 'mturk#review'
  match 'mturk/vote' => 'mturk#vote', :as => :vote

  match 'api/photo/submit' => 'photo_api#submit'

  match 'review/:action(/:id)' => 'review'
  match 'one_shot/:action(/:id)' => 'admin'
  
end