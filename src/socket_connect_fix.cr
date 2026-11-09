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
#
# The patch is applied only on Crystal releases that still carry the bug. From
# `SocketConnectFix::FIXED_IN` onwards it compiles to nothing and prints a note
# saying the shard can be removed; `-Dsocket_connect_fix_quiet` silences it.
#
# Compile with `-Dsocket_connect_fix_disabled` to leave `Socket#connect`
# untouched, e.g. to check whether the underlying Crystal bug is still present.
module SocketConnectFix
  VERSION = {{ `shards version #{__DIR__}`.chomp.stringify }}

  # First Crystal release whose own `Socket#connect` reports these failures,
  # making this shard unnecessary.
  FIXED_IN = "1.22.2"

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

{% if compare_versions(Crystal::VERSION, SocketConnectFix::FIXED_IN) >= 0 %}
  {% unless flag?(:socket_connect_fix_quiet) %}
    {% puts "socket_connect_fix: Crystal #{Crystal::VERSION.id} fixes this upstream; the shard is inert and can be removed. Pass -Dsocket_connect_fix_quiet to silence this." %}
  {% end %}
{% elsif flag?(:unix) && !flag?(:socket_connect_fix_disabled) %}
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
