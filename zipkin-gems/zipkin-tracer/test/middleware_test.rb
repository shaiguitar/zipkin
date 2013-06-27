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

  get '/' do
    'homepage'
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

  def test_apps_redirect_to_each_other
    resp = follow_redirects(@client, @client.get("/one"))
    assert_equal resp.body, "three"
  end

  def test_headers_generated_initial_request
    resp = @client.get("/")
    assert_equal resp.body, "homepage"
    assert resp.headers["X-B3-TraceId"], "no header!"
  #TODO The other special headers are X-B3-TraceId, X-B3-SpanId, X-B3-Sampled, and X-B3-Flags, though the names are transformed by Rack.
  # parent id nil, span id smth, sampled, flags...
  end

  #def test_headers_second_app
  #TODO
    # trace_id the same, parent id not nil, span id smth, sampled, flags...
    ## parent span id
    ## other info passed correctly
    #assert false
  #end

  #def test_whole_trace
  #TODO
  #...?
    #assert false
  #end

  private

  # rack-client helper
  def follow_redirects(client, client_resp)
    location = client_resp.headers["Location"]
    if location
      resp = client.get(location)
      client_resp = follow_redirects(client, resp)
    end
    return client_resp
  end

end



