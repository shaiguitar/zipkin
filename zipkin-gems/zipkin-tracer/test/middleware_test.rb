require 'test/unit'
require 'test_helper'


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

  def test_headers_initial_headers
    resp = @client.get("/")
    assert_equal resp.body, "homepage"
    assert resp.headers["X-B3-TraceId"], "should be trace id header"
    assert ! resp.headers["X-B3-ParentSpanId"], "should be no parent header"
    assert resp.headers["X-B3-SpanId"], "should be span header"
    #assert resp.headers["X-B3-Flags"], "flag header?"
    #assert resp.headers["X-B3-Sampled"], "sampled header?"
  end

  def test_headers_one_redirect
    resp = @client.get("/A")
    puts resp.headers.inspect
    orig_trace_id = resp.headers["X-B3-TraceId"]
    resp = @client.get(resp.headers["Location"])
    assert_equal resp.body, "B"
    puts resp.headers.inspect
    assert_equal resp.headers["X-B3-TraceId"], orig_trace_id
    assert resp.headers["X-B3-ParentSpanId"], "should be no parent header"
    assert resp.headers["X-B3-SpanId"], "should be span header"
    #assert resp.headers["X-B3-Flags"], "flag header?"
    #assert resp.headers["X-B3-Sampled"], "sampled header?"
  end

  #def test_whole_trace
    #TODO?
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



