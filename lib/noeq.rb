# **Noeq** generates GUIDs using [noeqd](https://github.com/bmizerany/noeqd).

# `noeqd` uses a simple TCP wire protocol, so let's require our only dependency,
# `socket`.
require 'socket'

class Noeq
  class ReadTimeoutError < StandardError; end
  class ReadError < StandardError; end

  DEFAULT_HOST = RUBY_PLATFORM =~ /darwin/ ? '127.0.0.1' : 'localhost'
  DEFAULT_PORT = 4444
  SECS_READ_TIMEOUT_FOR_SYNC = 0.1
  MAX_RETRIES = 3

  # If you just want to test out `noeq` or need to use it in a one-off script,
  # this method allows for very simple usage.
  def self.generate(n=1)
    noeq = new
    ids = noeq.generate(n)
    noeq.disconnect
    ids
  end

  def initialize(host = DEFAULT_HOST, port = DEFAULT_PORT)
    @host, @port = host, port
  end

  def disconnect
    # If the socket has already been closed by the other side, `close` will
    # raise, so we rescue it.
    @socket.close rescue false
  ensure
    @socket = nil
  end

  # The workhorse generate method. Defaults to one id, but up to 255 can be
  # requested.
  def generate(n=1)
    failures ||= 0

    if failures > 0
      disconnect
      connect
    elsif @socket.nil?
      connect
    end

    request_id(n)
    fetch_id(n)

  rescue Errno::ETIMEDOUT, Errno::ECONNREFUSED
    failures += 1
    retry if failures < MAX_RETRIES
    raise
  end

  def request_id(n=1)
    # The integer is packed into a binary byte and sent to the `noeqd` server.
    # The second argument to `BasicSocket#send` is a bitmask of flags, we don't
    # need anything special, so it is set to zero.
    @socket.send [n].pack('c'), 0
  end
  alias :request_ids :request_id

  def fetch_id(n=1)
    # We collect the ids from the `noeqd` server.
    ids = (1..n).map { get_id }.compact

    # If we have more than one id, we return the array, otherwise we return the
    # single id.
    ids.length > 1 ? ids : ids.first
  end
  alias :fetch_ids :fetch_id

  private

  def connect
    # We create a new TCP `STREAM` socket. There are a few other types of
    # sockets, but this is the most common.
    @socket = Socket.new(:INET, :STREAM)

    # If the connection fails after 0.5 seconds, immediately retry.
    set_socket_timeouts 0.5

    # In order to create a socket connection we need an address object.
    address = Socket.sockaddr_in(@port, @host)

    @socket.connect(address)
  end

  def set_socket_timeouts(timeout)
    secs = Integer(timeout)
    usecs = Integer((timeout - secs) * 1_000_000)
    optval = [secs, usecs].pack("l_2")
    @socket.setsockopt Socket::SOL_SOCKET, Socket::SO_RCVTIMEO, optval
    @socket.setsockopt Socket::SOL_SOCKET, Socket::SO_SNDTIMEO, optval
  end

  def get_id
    # `IO.select` blocks until one of the sockets passed in has an event
    # or a timeout is reached (the fourth argument)
    ready = IO.select([@socket], nil, nil, SECS_READ_TIMEOUT_FOR_SYNC)
    raise ReadTimeoutError unless ready

    # Since `select` has already blocked for us, we are pretty sure that
    # there is data available on the socket, so we try to fetch 8 bytes and
    # unpack them as a 64-bit big-endian unsigned integer.
    data = @socket.recv_nonblock(8)
    unpacked = data.unpack("Q>").first

    if unpacked.nil? 
      raise ReadError, "Error while reading from #{@host}:#{@port} data: #{data.inspect}"
    else
      unpacked
    end
  end
end
