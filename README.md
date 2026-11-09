# socket_connect_fix

> **Fixed upstream in Crystal 1.22.2.** On that release and later this shard
> compiles to nothing and prints a note on build. It remains available for
> projects still on an older Crystal; remove it once you have migrated.

On macOS (and possibly other BSD-derived systems), Crystal's `Socket#connect`
can report a refused connection as successful. The refusal is only visible in
the kernel's `SO_ERROR`, which Crystal does not read. Consequences:

- `TCPSocket.new("localhost", port)` stops at `::1` and never tries `127.0.0.1`,
  so servers listening only on IPv4 (e.g. Ollama) appear unreachable.
- Any refused connection returns a dead socket that fails later with a
  misleading error such as `getpeername: Invalid argument`.

This shard checks `SO_ERROR` after connect and reports failures as
`Socket::ConnectError`, so Crystal's existing address fallback works.

## Background

The kernel change arrived in macOS 26.7. A refused connection still sets
`SO_ERROR` to `ECONNREFUSED`, but a second `connect()` on the same socket now
answers `EISCONN` instead of repeating the error, and Crystal read that as
success. Blocking `connect()` was never affected. Confirmed on three Macs,
including one tested either side of the update, and absent on macOS 26.6.2 and
on Linux. Fixed upstream by crystal-lang/crystal#17436.

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

The patch is compiled in only on Crystal releases before 1.22.2, and on Unix
only. Elsewhere the shard is inert, so it is safe to keep in `shard.yml` while
a project migrates. It redefines `Socket#connect(addr, timeout, &)` and relies
on that signature.

CI runs the specs with Crystal 1.20 and the latest release on Linux and macOS,
and 1.20 on Windows. The specs assert the behaviour applications depend on, so
they pass whether it comes from this shard or from Crystal itself.

## Development

```sh
crystal spec
crystal spec -Devloop=libevent
crystal spec -Dsocket_connect_fix_disabled   # before 1.22.2 on macOS, closed-port specs should fail
```

`-Dsocket_connect_fix_quiet` silences the build-time note on Crystal 1.22.2
and later.

## Contributions, by invitation!

*With apologies*, at this time contributions to this project are *by invitation only* and limited to people I know and see often.

- These are early days for the project and I am busy with family and work.
- At this time I want to work on this at a manageable pace.
