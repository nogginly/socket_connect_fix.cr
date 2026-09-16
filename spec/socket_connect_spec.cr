require "spec"
require "../src/socket_connect_fix"

private def closed_port(host) : Int32
  server = TCPServer.new(host, 0)
  port = server.local_address.port
  server.close
  port
end

describe SocketConnectFix do
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

  {% if flag?(:windows) %}
    it "reports connection error (Windows)" do
      expect_raises(Socket::ConnectError) do
        TCPSocket.new("10.255.255.1", 81, connect_timeout: 0.2)
      end
    end

    pending "reports timeouts unchanged (Unix)" do; end
  {% else %}
    it "reports timeouts unchanged (Unix)" do
      expect_raises(IO::TimeoutError) do
        TCPSocket.new("10.255.255.1", 81, connect_timeout: 0.2)
      end
    end

    pending "reports connection error (Windows)" do; end
  {% end %}
end
