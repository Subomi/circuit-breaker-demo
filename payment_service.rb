require 'sinatra/base'
require 'sinatra/json'

class Server < Sinatra::Base
  
  set :port, 9070

  post '/payment/:user_id' do 
    sleep (4..5).to_a.sample
    
    data = { 
      status: true,
      message: 'Payment made successfully',
      data: {}
    }

    json(data)
  end
end
