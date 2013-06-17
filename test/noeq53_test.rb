require 'test/unit'
require 'mocha'
require './lib/noeq53'

class Noeq53SimpleTest < Test::Unit::TestCase

  def setup
    FakeNoeq53.start
  end

  def teardown
    FakeNoeq53.stop
  end

  def test_simple_generate
    assert_equal expected_id, Noeq53.generate
  end

  def test_multiple_generate
    noeq = Noeq53.new
    assert_equal [expected_id]*3, noeq.generate(3)
  end

  def test_different_port
    FakeNoeq53.stop
    FakeNoeq53.start(4545)

    noeq = Noeq53.new(Noeq53::DEFAULT_HOST, 4545)
    assert_equal expected_id, noeq.generate
  end

  def test_reconnect
    noeq = Noeq53.new
    assert noeq.generate

    FakeNoeq53.stop
    FakeNoeq53.start

    assert_equal expected_id, noeq.generate
  end


  private

  def expected_id
    82257233859
  end
end

class NoeqdFailureConditionTest < Test::Unit::TestCase

  def teardown
    FakeNoeq53.stop
  end

  def test_connection_errors_on_generate_will_be_retried_upto_3_times
    FakeNoeq53.start
    [Errno::ECONNREFUSED, Errno::ETIMEDOUT, Errno::EPIPE].each do |error|
      noeq = Noeq53.new(Noeq53::DEFAULT_HOST, 4444)
      noeq.expects(:connect).times(3).raises(error)
      assert_raises(error) do
        noeq.generate(100)
      end
    end
  end

  def test_sync_request_with_unresponsive_server_after_connect_raises
    FakeNoeq53.start(5555, :action => :block_read)
    noeq = Noeq53.new(Noeq53::DEFAULT_HOST, 5555)
    assert_raises(Noeq53::ReadTimeoutError){  noeq.generate }
  end

  def test_sync_request_with_disconnecting_server_after_connect_raises
    FakeNoeq53.start(5555, :action => :disconnect_read)
    noeq = Noeq53.new(Noeq53::DEFAULT_HOST, 5555)
    assert_raises(Noeq53::EOFError){  noeq.generate }
  end

  def test_generate_when_server_never_accepts_raises
    FakeNoeq53.start(5556, :action => :never_accept)
    noeq = Noeq53.new(Noeq53::DEFAULT_HOST, 5556)
    assert_raises(Noeq53::ReadTimeoutError){  noeq.generate }
  end

  def test_generate_receiving_short_response_raises
    FakeNoeq53.start(5557, :action => :short_write)
    noeq = Noeq53.new(Noeq53::DEFAULT_HOST, 5557)
    assert_raises(Noeq53::ReadError){  noeq.generate }
  end

  def test_generate_receiving_long_response_raises
    FakeNoeq53.start(5558, :action => :long_write)
    noeq = Noeq53.new(Noeq53::DEFAULT_HOST, 5558)
    assert_raises(Noeq53::ReadError){  noeq.generate; noeq.generate }
  end
end

class FakeNoeq53

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
          cmd = conn.read(2)
          n, idspace = cmd.unpack('cc')
          return conn.close if @options[:action] == :disconnect_read

          if @options[:action] == :block_read
            sleep(100)
          end
          data = "\x00\x00\x00\x13&\xE9\xC7\xC3"
          if @options[:action] == :short_write
            data = data[0..6]
          elsif @options[:action] == :long_write
            data = data + "\xC0"
          end
          conn.send data * n, 0
        end
      end
    end
  end
end
