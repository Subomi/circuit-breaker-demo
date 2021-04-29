require 'sinatra/base'
require 'sinatra/required_params'
require 'sinatra/json'
require 'httparty'
require 'circuitbox'

class PaymentService
  class FailedRequest < StandardError
  end

  include HTTParty
  base_uri '10.128.0.8:9070'

  def initialize(user_id)
    @user_id = user_id
  end

  def make_payment
    self.class.post("/payment/#{@user_id}", body: body.to_json, timeout: 5)
  end

  def body
    {}
  end
end

module ErrorHandler
  def error_response
    {
      status: false, 
      message: 'Something went wrong, please try again'
    }
  end
end

class PayDecoratedWithCircuitbox
  include ErrorHandler

  class << self
    def register_subscribers
      ActiveSupport::Notifications.subscribe('circuit_open') do |name, start, finish, id, payload|
        circuit_name = payload[:circuit]
        Logger.new(STDOUT).warn("Open circuit for: #{circuit_name} on worker: #{$0}")
      end

      ActiveSupport::Notifications.subscribe('circuit_close') do |name, start, finish, id, payload|
        circuit_name = payload[:circuit]
        Logger.new(STDOUT).info("Close circuit for: #{circuit_name} on worker: #{$0}")
      end
    end
  end

  def initialize(user_id)
    @user_id = user_id
  end

  def call
    response = circuit.run do 
      PaymentService.new(@user_id).make_payment
    end

    return response.parsed_response unless response.nil?
    error_response
  end

  private 

  def circuit
    Circuitbox.circuit(:paystack, circuit_breaker_configuration)
  end

  def circuit_breaker_configuration
    logger = Logger.new(STDOUT)
    logger.level = Logger::FATAL
    {
      exceptions: [Net::ReadTimeout],
      logger: logger,
      time_window: 60,
      volume_threshold: 5,
      error_threshold: 70
    }
  end
end

class PayDecoratedWithSemian
  include ErrorHandler
end

class Server < Sinatra::Base
  helpers Sinatra::RequiredParams

  post '/unprotected_pay' do 
    service = PaymentService.new(80)
    response = service.make_payment

    json(response)
  end

  post '/semain_protected_pay' do 

    service = PayDecoratedWithSemian.new(80)
    response = service.call

    json(response)
  end

  post '/circuitbox_protected_pay' do

    service = PayDecoratedWithCircuitbox.new(80)
    response = service.call

    json(response)
  end
end

PayDecoratedWithCircuitbox.register_subscribers
