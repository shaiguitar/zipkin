require 'test/unit'
require 'test_helper'

class ZipkinConfig
  def self.zipkin_tracer
    {service_name: 'some_app', service_port: 9410, sample_rate: 1, scribe_server: "127.0.0.1:9410"}
  end
end

class App < Sinatra::Base

  def self.config
    ZipkinConfig
  end

  get '/one' do
    redirect "/prefix/two"
  end
  get '/three' do
    "three"
  end
end

class AppTwo < Sinatra::Base

  def self.config
    ZipkinConfig
  end

  get '/two' do
    redirect "/three"
  end
end

class MainApplication
  def self.app
    Rack::Builder.new do
      map("/")    { use ZipkinTracer::RackHandler; run App }
      map("/prefix/") { use ZipkinTracer::RackHandler; run AppTwo }
    end
  end
end

MainApplication.app

class TestAdd < Test::Unit::TestCase

  def setup
    url = "http://some.app"
    @client = Rack::Client.new(url) do
      run MainApplication.app
    end
  end

  def test_middleware_works
    @client.get("/one")
  end
end



