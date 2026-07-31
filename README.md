# Swift AsyncAPI Runtime

`AsyncAPIRuntime` is the small, transport-neutral foundation used by Swift
interfaces generated from AsyncAPI documents. It defines channels, messages,
close signals, connections, and the protocol a server transport implements.

Most applications should use this package through generated code and a
framework adapter. Use it directly when implementing an adapter or another
code generator.

## Requirements

- Swift 6.2 or later
- macOS 15 or later
- iOS 18 or later
- Linux with a Swift 6.2 toolchain

The library has no third-party package dependencies and does not import a web
framework.

## Installation

Add the package to `Package.swift` and pin the release expected by your
generated source and transport adapter:

```swift
dependencies: [
  .package(
    url: "https://github.com/soenan-apps/swift-asyncapi-runtime.git",
    exact: "0.1.0"
  )
]
```

Then add the product to the target that compiles generated interfaces or a
transport implementation:

```swift
.product(
  name: "AsyncAPIRuntime",
  package: "swift-asyncapi-runtime"
)
```

## Minimal use

A transport registers a channel and receives a connection when that channel
is opened:

```swift
import AsyncAPIRuntime

let events = try AsyncAPIChannel(
  name: "roomEvents",
  address: "/rooms/{roomId}/events",
  parameterNames: ["roomId"]
)

func register<T: AsyncAPIServerTransport>(on transport: T) throws
where T.ApplicationContext == Void {
  try transport.register(channel: events) { connection in
    for try await message in connection.messages {
      switch message {
      case .text(let text):
        try await connection.send(.text(text))
      case .binary(let bytes):
        try await connection.send(.binary(bytes))
      }
    }
  }
}
```

Generated server registrations build this boundary for each AsyncAPI channel,
including typed message decoding and encoding. Application code normally
implements the generated handler protocol instead of switching over
`AsyncAPITransportMessage` itself.

## API

### Channels

`AsyncAPIChannel` stores a channel name, address, and ordered parameter names.
Construction validates the complete route grammar so adapters do not reinterpret
an ambiguous address.

Accepted addresses start with `/` and contain literal segments or
whole-segment parameters such as `{roomId}`. Literal segments use URI
unreserved ASCII characters. The declared `parameterNames` must be unique and
match the address in order.

Queries, fragments, wildcards, framework-specific `:parameter` syntax,
partial-segment parameters, empty segments, dot segments, percent encoding,
and non-ASCII literals are rejected.

### Messages and connections

`AsyncAPITransportMessage` carries one complete text or binary message.
`AsyncAPIConnection<ApplicationContext>` exposes:

- transport-established, strongly typed `applicationContext`;
- extracted channel `parameters`;
- an asynchronous stream of incoming `messages`;
- transport operations through `send(_:)` and `close(_:)`.

Use `AsyncAPIConnection<Void>` when a channel does not need application-owned
context. The specialized initializer supplies `()` automatically.

### Server transports

`AsyncAPIServerTransport<ApplicationContext>` is the registration boundary
implemented by framework adapters. Its `ApplicationContext` must match the
context expected by the generated handler. This preserves authentication or
authorization evidence without runtime casts or global state.

### Close signals

`AsyncAPICloseCode` accepts WebSocket codes that may be sent on the wire:
standard codes `1000...1003` and `1007...1014`, plus application codes
`3000...4999`. Reserved codes such as `1005` and `1006` are rejected.

`AsyncAPICloseSignal` limits its reason to 123 UTF-8 bytes, the maximum payload
available after the two-byte close code in a WebSocket control frame.

## Generator and adapter relationship

The packages have one-way responsibilities:

1. An AsyncAPI generator emits typed channel, message, session, and registration
   interfaces that import `AsyncAPIRuntime`.
2. This runtime supplies stable transport-neutral values and protocols.
3. A framework adapter implements `AsyncAPIServerTransport` and bridges its
   native socket implementation to `AsyncAPIConnection`.
4. Application code implements the generated handler protocol.

The runtime does not depend on generated code or a framework adapter.

## Versioning

Releases follow Semantic Versioning. While the package is below `1.0.0`, a
minor release may contain source-breaking API changes. Generated source,
runtime, and transport adapters should use a documented compatible release set;
pin exact versions when reproducible code generation is required.

## Non-goals

This package does not:

- parse or validate AsyncAPI documents;
- generate Swift source;
- open sockets or implement HTTP/WebSocket upgrades;
- authenticate users or authorize channels;
- define buffering, backpressure, reconnection, or application message policy.

Those responsibilities belong to the generator, framework adapter, or
application as appropriate.

## Testing

Run the formatting and test gates with the Swift 6.2 toolchain:

```sh
swift format lint --strict --recursive Sources Tests Package.swift
swift test
```

The tests cover channel grammar, WebSocket close-code and reason limits,
connection delegation, application-context typing, and transport registration.

## License

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) and
[NOTICE](NOTICE).
