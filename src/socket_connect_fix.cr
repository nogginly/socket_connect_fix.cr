require "socket"

# Requiring this file changes `Socket#connect` for the whole program.
#
# After the event loop reports a connection as established, the kernel's pending
# socket error (`SO_ERROR`) is checked. A non-zero value is yielded as a
# `Socket::ConnectError`, exactly as an immediate failure would be.
#
# Effects:
# - `TCPSocket.new(host, port)` tries the next resolved address when an earlier
#   one refused, e.g. `localhost` falls back from `::1` to `127.0.0.1`.
# - A refused connection raises `Socket::ConnectError` at construction instead of
#   returning a socket that fails on first use.
#
# Applies to every `TCPSocket`, including those created by `HTTP::Client` and
# database drivers. Has no effect on Windows.
module SocketConnectFix
  VERSION = "0.1.0"

  {% if flag?(:darwin) || flag?(:bsd) %}
    SO_ERROR = 0x1007
  {% elsif flag?(:linux) %}
    SO_ERROR = 4
  {% end %}

  # Returns the pending error on *socket* and clears it; `0` means none.
  def self.pending_error(socket : ::Socket) : Int32
    {% if flag?(:unix) %}
      value = 0
      len = LibC::SocklenT.new(sizeof(Int32))
      if LibC.getsockopt(socket.fd, LibC::SOL_SOCKET, SO_ERROR, pointerof(value), pointerof(len)) == -1
        return Errno.value.value
      end
      value
    {% else %}
      0
    {% end %}
  end
end

{% if flag?(:unix) %}
  class Socket
    def connect(addr, timeout = nil, &)
      failed = false
      result = previous_def(addr, timeout) do |error|
        failed = true
        yield error
      end
      return result if failed

      errno = SocketConnectFix.pending_error(self)
      yield Socket::ConnectError.from_os_error("connect", Errno.new(errno)) unless errno == 0
    end
  end
{% end %}
