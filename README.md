# socket_connect_fix

On macOS (and possibly other BSD-derived systems), Crystal's `Socket#connect`
can report a refused connection as successful. The refusal is only visible in
the kernel's `SO_ERROR`, which Crystal does not read. Consequences:

- `TCPSocket.new("localhost", port)` stops at `::1` and never tries `127.0.0.1`,
  so servers listening only on IPv4 (e.g. Ollama) appear unreachable.
- Any refused connection returns a dead socket that fails later with a
  misleading error such as `getpeername: Invalid argument`.

This shard checks `SO_ERROR` after connect and reports failures as
`Socket::ConnectError`, so Crystal's existing address fallback works.

## Installation

```yaml
dependencies:
  socket_connect_fix:
    github: nogginly/socket_connect_fix.cr
```

## Usage

```crystal
require "socket_connect_fix"
```

Require it once, anywhere in the application. The change applies to every
socket in the program, including those opened by `HTTP::Client` and database
drivers. Libraries should not require it; applications opt in.

## Compatibility

Tested against Crystal 1.21.0 on Linux (polling event loop). Unix only; a no-op
on Windows. It redefines `Socket#connect(addr, timeout, &)` and relies on that
signature. Re-run the specs when upgrading Crystal, and remove the shard once
the upstream fix ships.

## Development

```sh
crystal spec
crystal spec -Devloop=libevent
```

## Contributions, by invitation!

*With apologies*, at this time contributions to this project are *by invitation only* and limited to people I know and see often.

- These are early days for the project and I am busy with family and work.
- At this time I want to work on this at a manageable pace.
