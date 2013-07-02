require 'test_helper'


class TestRackClient < Test::Unit::TestCase

  def setup
    @client = TestHelpers.client
  end

  def test_norpc
    resp = @client.get("/first_app/norpc")
    # want to assert that if the client were to make another request, it would be in the same trace_id
    tracer = @client.get_current_tracer
    tracer.trace_id == resp.headers["X-B3-TraceId"]
  end

end
