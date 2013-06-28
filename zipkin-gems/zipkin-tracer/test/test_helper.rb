require File.dirname(__FILE__) + "/../lib/zipkin-tracer"
require 'sinatra'
require 'pry'
require 'rack'
require 'rack/client'

module TestHelpers

  def self.client
    @client = Rack::Client.new(TestHelpers.url) do
      run MainApplication.app
    end
  end

  def self.url
    "http://some.place"
  end

  class ZipkinConfig
    def self.zipkin_tracer
      {service_name: 'some_app', service_port: 9410, sample_rate: 1, scribe_server: "127.0.0.1:9410"}
    end
  end

  class FirstApp < Sinatra::Base
    def self.config; ZipkinConfig; end

    get '/start' do
      TestHelpers.client.get(TestHelpers.url + "/second_app/continue")
      "made request to /second_app/continue"
    end

    get '/simple' do
      TestHelpers.client.get(TestHelpers.url + "/third_app/end")
      "made request to /third_app/end"
    end

    get '/end' do
      "end"
    end

  end

  class SecondApp < Sinatra::Base
    def self.config; ZipkinConfig; end

    get '/continue' do
      TestHelpers.client.get(TestHelpers.url + "/first_app/end")
      TestHelpers.client.get(TestHelpers.url + "/third_app/continue")
      "made request to /first_app/end AND /third_app/continue"
    end

  end

  class ThirdApp < Sinatra::Base
    def self.config; ZipkinConfig; end

    get '/continue' do
      TestHelpers.client.get(TestHelpers.url + "/first_app/end")
      "made request to /first_app/end"
    end

    get '/end' do
    end

  end

  ## web of api requests to simulate: 
  #
  # /first_app/start
  # => /second_app/continue
  #   => /first_app/end
  #   => /third_app/continue
  #     => /first_app/end
  #
  # /first_app/simple
  # => /third_app/end
  #
  # main assertions need to do figure 2 in
  # http://static.googleusercontent.com/external_content/untrusted_dlcp/research.google.com/en/us/pubs/archive/36356.pdf
  # they are: TODO
  #
 
  class MainApplication
    def self.app
      Rack::Builder.new do
        map("/first_app/")    { use ZipkinTracer::RackHandler; run FirstApp }
        map("/second_app/") { use ZipkinTracer::RackHandler; run SecondApp }
        map("/third_app/") { use ZipkinTracer::RackHandler; run ThirdApp }
      end
    end
  end

end
