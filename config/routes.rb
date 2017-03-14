Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  root to: 'home#index'

  get '/template/:template_name' => 'home#template'
  get '/random_image' => 'home#random_image'

end
