require "spec"
require "../src/socket_connect_fix"

private def closed_port(host) : Int32
  server = TCPServer.new(host, 0)
  port = server.local_address.port
  server.close
  port
end

# These specs assert the behaviour applications depend on, whether it comes
# from this shard or from Crystal itself, so they pass on every supported
# version.
describe SocketConnectFix do
  it "reports the Crystal release that makes the shard inert" do
    SocketConnectFix::FIXED_IN.should_not be_empty
    {% if compare_versions(Crystal::VERSION, SocketConnectFix::FIXED_IN) >= 0 %}
      puts "  (Crystal #{Crystal::VERSION} has the upstream fix; the patch is not compiled in.)"
    {% end %}
  end

  it "raises Socket::ConnectError when the port is closed" do
    port = closed_port("127.0.0.1")
    expect_raises(Socket::ConnectError) do
      TCPSocket.new("127.0.0.1", port)
    end
  end

  it "connects to a listening IPv4 server" do
    server = TCPServer.new("127.0.0.1", 0)
    client = TCPSocket.new("127.0.0.1", server.local_address.port)
    client.remote_address.port.should eq(server.local_address.port)
  ensure
    client.try &.close
    server.try &.close
  end

  it "falls back to 127.0.0.1 when localhost resolves ::1 first" do
    addresses = Socket::Addrinfo.tcp("localhost", 80).map(&.ip_address.address)
    unless addresses.first? == "::1" && addresses.includes?("127.0.0.1")
      pending!("localhost does not resolve to ::1 then 127.0.0.1 here: #{addresses}")
    end

    server = TCPServer.new("127.0.0.1", 0)
    client = TCPSocket.new("localhost", server.local_address.port)
    client.remote_address.address.should eq("127.0.0.1")
  ensure
    client.try &.close
    server.try &.close
  end

  it "reports timeouts unchanged" do
    TCPSocket.new("10.255.255.1", 81, connect_timeout: 0.2).close
    fail "expected the connection attempt to fail"
  rescue ex : IO::TimeoutError
  rescue ex : Socket::ConnectError
    pending!("10.255.255.1 is not blackholed on this network: #{ex.message}")
  end
end
