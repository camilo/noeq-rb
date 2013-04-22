require 'test/unit'
require 'mocha'
require './lib/noeq'

class NoeqSimpleTest < Test::Unit::TestCase

  def setup
    FakeNoeqd.start
  end

  def teardown
    FakeNoeqd.stop
  end

  def test_simple_generate
    assert_equal expected_id, Noeq.generate
  end

  def test_multiple_generate
    noeq = Noeq.new
    assert_equal [expected_id]*3, noeq.generate(3)
  end

  def test_different_port
    FakeNoeqd.stop
    FakeNoeqd.start(4545)

    noeq = Noeq.new(Noeq::DEFAULT_HOST, 4545)
    assert_equal expected_id, noeq.generate
  end

  def test_reconnect
    noeq = Noeq.new
    assert noeq.generate

    FakeNoeqd.stop
    FakeNoeqd.start

    assert_equal expected_id, noeq.generate
  end


  private

  def expected_id
    144897448664367104
  end
end

class NoeqdFailureConditionTest < Test::Unit::TestCase

  def teardown
    FakeNoeqd.stop
  end

  def test_connection_errors_on_generate_will_be_retried_upto_3_times
    FakeNoeqd.start
    [Errno::ECONNREFUSED, Errno::ETIMEDOUT, Errno::EPIPE].each do |error|
      noeq = Noeq.new(Noeq::DEFAULT_HOST, 4444)
      noeq.expects(:connect).times(3).raises(error)
      assert_raises(error) do
        noeq.generate(100)
      end
    end
  end

  def test_sync_request_with_unresponsive_server_after_connect_raises
    FakeNoeqd.start(5555, :action => :block_read)
    noeq = Noeq.new(Noeq::DEFAULT_HOST, 5555)
    assert_raises(Noeq::ReadTimeoutError){  noeq.generate }
  end

  def test_sync_request_with_disconnecting_server_after_connect_raises
    FakeNoeqd.start(5555, :action => :disconnect_read)
    noeq = Noeq.new(Noeq::DEFAULT_HOST, 5555)
    assert_raises(Noeq::ReadTimeoutError){  noeq.generate }
  end

  def test_generate_when_server_never_accepts_raises
    FakeNoeqd.start(5556, :action => :never_accept)
    noeq = Noeq.new(Noeq::DEFAULT_HOST, 5556)
    assert_raises(Noeq::ReadTimeoutError){  noeq.generate }
  end

  def test_generate_receiving_short_response_raises
    FakeNoeqd.start(5557, :action => :short_write)
    noeq = Noeq.new(Noeq::DEFAULT_HOST, 5557)
    assert_raises(Noeq::ReadError){  noeq.generate }
  end

  def test_generate_receiving_long_response_raises
    FakeNoeqd.start(5558, :action => :long_write)
    noeq = Noeq.new(Noeq::DEFAULT_HOST, 5558)
    assert_raises(Noeq::ReadError){  noeq.generate; noeq.generate }
  end
end

class FakeNoeqd

  def self.start(port = 4444, options = {})
    @server = new(port, options)
    @thread = Thread.new { @server.accept_connections }
  end

  def self.stop
    @server.stop if @server
  end

  def initialize(port, options)
    @options = options
    @socket = TCPServer.new(port)
  end

  def stop
    @socket.close rescue true
    @thread.kill rescue true
  end

  def accept_connections
    if @options[:action] == :never_accept
      while true
        sleep(100)
      end
    else
      while conn = @socket.accept
        while true
          n = conn.read(1)
          return @socket.close if @options[:action] == :disconnect_read
          if @options[:action] == :block_read
            sleep(100)
          end
          data = "\x02\x02\xC7v<\x80\x00\x00"
          if @options[:action] == :short_write
            data = "\x02\x02v<\x80\x00\x00"
          elsif @options[:action] == :long_write
            data = "\x02\x02\xC7v<\x80\x00\x00\x00"
          end
          conn.send data * n.unpack('c')[0], 0
        end
      end
    end
  end
end
