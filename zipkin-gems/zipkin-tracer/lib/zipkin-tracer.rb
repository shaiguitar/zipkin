# Copyright 2012 Twitter Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
require 'finagle-thrift'
require 'finagle-thrift/trace'
require 'scribe'

require 'zipkin-tracer/careless_scribe'

module ZipkinTracer extend self

  class RackHandler
    def initialize(app)
      @app = app
      @lock = Mutex.new

      config = app.config.zipkin_tracer
      @service_name = config[:service_name]
      @service_port = config[:service_port]

      scribe =
        if config[:scribe_server] then
          Scribe.new(config[:scribe_server])
        else
          Scribe.new()
        end

      scribe_max_buffer =
        if config[:scribe_max_buffer] then
          config[:scribe_max_buffer]
        else
          10
        end

      @sample_rate =
        if config[:sample_rate] then
          config[:sample_rate]
        else
          0.1
        end

      ::Trace.tracer = ::Trace::ZipkinTracer.new(CarelessScribe.new(scribe), scribe_max_buffer)
    end


    def call(env)
      generate_thread_locals(env)
      puts thread_locals.inspect
      id = ::Trace::TraceId.new(thread_locals[:trace_id], thread_locals[:parent_id],
                                thread_locals[:span_id], true, ::Trace::Flags::EMPTY)
      ::Trace.default_endpoint = ::Trace.default_endpoint.with_service_name(@service_name).with_port(@service_port)
      ::Trace.sample_rate=(@sample_rate)
      tracing_filter(id, env) { @app.call(env) }
    end

    private

    def generate_thread_locals(env)

      # either set from header, or generate new one
      trace_id = (env["HTTP_X_TRACE_ID"] && !env['HTTP_X_TRACE_ID'].empty? && env["HTTP_X_TRACE_ID"].to_i)  || ::Trace.generate_id
      # either set from header, or generate new one
      span_id = (env["HTTP_X_SPAN_ID"] && env["HTTP_X_SPAN_ID"].to_i)  || ::Trace.generate_id
      # parent id explicitly set by header, or it needs to be nil.
      parent_id = (env["HTTP_X_PARENT_ID"] && !env['HTTP_X_PARENT_ID'].empty? && env["HTTP_X_PARENT_ID"].to_i)

      Thread.current[:zipkin] = {
        trace_id: trace_id,
        span_id: span_id,
        parent_id: parent_id,
      }
    end

    def thread_locals
      Thread.current[:zipkin]
    end


    def tracing_filter(trace_id, env)
      @lock.synchronize do
        ::Trace.push(trace_id)
        ::Trace.set_rpc_name(env["REQUEST_METHOD"]) # get/post and all that jazz
        ::Trace.record(::Trace::BinaryAnnotation.new("http.uri", env["PATH_INFO"], "STRING", ::Trace.default_endpoint))
        ::Trace.record(::Trace::Annotation.new(::Trace::Annotation::SERVER_RECV, ::Trace.default_endpoint))
      end
      yield if block_given?
    ensure
      @lock.synchronize do
        ::Trace.record(::Trace::Annotation.new(::Trace::Annotation::SERVER_SEND, ::Trace.default_endpoint))
        ::Trace.pop
      end
    end
  end

end
