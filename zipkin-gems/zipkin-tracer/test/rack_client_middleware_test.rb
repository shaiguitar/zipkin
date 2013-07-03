require 'test_helper'


class TestRackClient < Test::Unit::TestCase

  def setup
    @client = TestHelpers.client
    TestHelpers.bootrelwebs
  end
  def teardown
    TestHelpers.killrealwebs
  end

  def test_one_rpc_request
    puts ENV.inspect

    server_location = TestHelpers.first_app
    resp = @client.get("#{server_location}/simple")
  end

end
