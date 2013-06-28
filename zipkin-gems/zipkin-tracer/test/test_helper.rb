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

    get '/norpc' do
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

  # main assertions need to do figure 2 in
  # http://static.googleusercontent.com/external_content/untrusted_dlcp/research.google.com/en/us/pubs/archive/36356.pdf
  #
  # SHARED:
  # =======
  #
  # assert that we have client start, server recv, server send, client receive, http uri/method, annotations in spans.
  #
  ## WEB OF API REQUESTS TO SIMULATE: 
  # =================================
  #
  # => /first_app/norpc
  #
  # assert a single span in a trace, with no parent id (but still has the shared attribute annotations as above)
  #
  # => /first_app/simple
  #   => /third_app/end
  #
  # assert that all the annotations we have should coorelate to two spans: one span for '/simple' and another for '/end'
  # assert trace id is the same for both spans and belong to it
  # assert the first span has no parent id, second span has a parent id of the first.
  #
  # => /first_app/start
  #   => /second_app/continue
  #     => /first_app/end
  #     => /third_app/continue
  #       => /first_app/end
  #  
  # assert there are 5 spans in this one trace. all have same trace_id: ( num below really just a hex code)
  # span: /first_app/start, parent_id=nil, span_id=1
  # span: /second_app/continue, parent_id=1, span_id=2
  # span: /first_app/end, parent_id=2, span_id=3
  # span: /third_app/continue, parent_id=2, span_id=4
  # span: /first_app/end, parent_id=4, span_id=5

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
