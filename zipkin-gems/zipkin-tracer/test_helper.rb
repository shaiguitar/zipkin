$: << "."
$: << "lib"
require File.dirname(__FILE__) + "/lib/zipkin-tracer"
require 'sinatra'
require 'pry'
require 'rack'
require 'rack/client'
require 'test/unit'
require 'base64'
require 'realweb'
require 'redis'

module TestHelpers

  class ForwardHeaders
    def initialize(app)
      @app = app
      @trace_id = TestHelpers.thread_locals[:trace_id]
      # from the client perspective it's going to start a new span, so we just generate a new span_id
      # and use the server's current span_id for it being the parent of the next rpc request that is going to happen.
      @parent_id = TestHelpers.thread_locals[:span_id]
      @lock = Mutex.new
    end

    def call(env)

      trace_id = @trace_id && @trace_id.to_s
      parent_id = @parent_id && @parent_id.to_s
      span_id = ::Trace.generate_id.to_s

      # SET THE HEADERS SO NEXT REQUEST IT MAKES THOSE HEADERS GET PASSED
      env["HTTP_X_TRACE_ID"] = trace_id.to_s
      env["HTTP_X_SPAN_ID"] = span_id.to_s
      env["HTTP_X_PARENT_ID"] = parent_id.to_s

      # we can rely on ::Trace being set, because the client using this middleware should call within the server 
      # context, which means it has access to those thread_locals and the Trace thingie.
      # however, it's different because CS,CR are the boundries of a new span, so we need to have that information 
      # be correct.

      id = ::Trace::TraceId.new(trace_id && trace_id.to_i, parent_id && parent_id.to_i, span_id && span_id.to_i, true, ::Trace::Flags::EMPTY)
      client_tracing_filter(id, env) { @app.call(env) }
 #     @app.call(env)
    end

    private

    def client_tracing_filter(trace_id, env)
      @lock.synchronize do
        ::Trace.push(trace_id)
        ::Trace.set_rpc_name(env["REQUEST_METHOD"]) # get/post and all that jazz
        ::Trace.record(::Trace::BinaryAnnotation.new("http.uri", env["PATH_INFO"], "STRING", ::Trace.default_endpoint))
        ::Trace.record(::Trace::Annotation.new(::Trace::Annotation::CLIENT_SEND, ::Trace.default_endpoint))
      end
      yield if block_given?
    ensure
      @lock.synchronize do
        ::Trace.record(::Trace::Annotation.new(::Trace::Annotation::CLIENT_RECV, ::Trace.default_endpoint))
        ::Trace.pop
      end
   end

  end

  def self.client
    Rack::Client.new do
      use ForwardHeaders
      run Rack::Client::Handler::NetHTTP
    end
  end

  # convention
  def self.first_app
    "http://localhost:7777"
  end
  def self.second_app
    "http://localhost:7778"
  end
  def self.third_app
    "http://localhost:7779"
  end

  class ZipkinConfig
    def initialize(from)
      @from = from.to_s.split(':').last
    end
    def zipkin_tracer
      {service_name: @from.to_s, service_port: 9410, sample_rate: 1, scribe_server: "127.0.0.1:9410"}
    end
  end

  def self.thread_locals
    Thread.current[:zipkin]
  end

  class FirstApp < Sinatra::Base
    def self.config; ZipkinConfig.new(self); end
    get '/simple' do
      puts "handling simple"
      puts env.inspect
      # GET THE HEADERS FROM REQUEST TO SERVER AND SEE IF WE HAVE INFOZ SO WE CAN PASS TO NEXT RPC
      r = TestHelpers.client.get(TestHelpers.second_app + "/end")
      response = r.body
      "made request to /second_app/end. Got response = #{response}"
    end
    
    get '/complicated' do
      puts "handling complicated"
      puts env.inspect
      # GET THE HEADERS FROM REQUEST TO SERVER AND SEE IF WE HAVE INFOZ SO WE CAN PASS TO NEXT RPC
      r = TestHelpers.client.get(TestHelpers.second_app + "/end")
      r1 = r.body
      r = TestHelpers.client.get(TestHelpers.third_app + "/continue")
      r2 = r.body
      "made request to /second_app/end. Got response = #{r1}" +\
        "made request to /third_app/continue. Got response = #{r2}"
    end

  end

  class SecondApp < Sinatra::Base
    def self.config; ZipkinConfig.new(self); end
    get '/end' do
      puts "handling end in second app"
      puts env.inspect
      "handling end in second app"
    end
  end

  class ThirdApp < Sinatra::Base
    def self.config; ZipkinConfig.new(self); end
    get '/continue' do
      puts "handling continue in third app"
      puts env.inspect
      r = TestHelpers.client.get(TestHelpers.second_app + "/end")
      response = r.body
      "handling continue in third app. got response from second = #{response}"
    end
  end


end
