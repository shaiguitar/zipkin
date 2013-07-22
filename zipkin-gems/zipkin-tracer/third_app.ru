$: << "."
require './test_helper'
require './lib/zipkin-tracer'
require './lib/zipkin-tracer/careless_scribe'

use ZipkinTracer::RackHandler; run TestHelpers::ThirdApp

