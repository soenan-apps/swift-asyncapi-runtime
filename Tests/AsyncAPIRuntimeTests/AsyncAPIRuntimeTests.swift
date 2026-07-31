import AsyncAPIRuntime
import Testing

@Test
func channelRequiresAnExactParameterizedPath() throws {
  let channel = try AsyncAPIChannel(
    name: "roomEvents",
    address: "/rooms/{roomId}/events",
    parameterNames: ["roomId"]
  )
  #expect(channel.parameterNames == ["roomId"])

  let root = try AsyncAPIChannel(
    name: "rootEvents",
    address: "/",
    parameterNames: []
  )
  #expect(root.address == "/")

  #expect(throws: AsyncAPIRuntimeError.invalidChannel) {
    try AsyncAPIChannel(
      name: "roomEvents",
      address: "/rooms/events?roomId={roomId}",
      parameterNames: ["roomId"]
    )
  }

  #expect(throws: AsyncAPIRuntimeError.invalidChannel) {
    try AsyncAPIChannel(
      name: "roomEvents",
      address: "/rooms/{roomId}/{missing}/events",
      parameterNames: ["roomId"]
    )
  }

  #expect(throws: AsyncAPIRuntimeError.invalidChannel) {
    try AsyncAPIChannel(
      name: "roomEvents",
      address: "/rooms/{room-id}/events",
      parameterNames: ["room-id"]
    )
  }

  for address in [
    "/events/*",
    "/events/:eventId",
    "/events/prefix-{eventId}",
    "/events/{eventId}-suffix",
    "/events//live",
    "/events/",
    "/events/../live",
    "/events/%2A",
    "/events/a:b",
    "/events/back\\slash",
    "/events/日本語",
  ] {
    #expect(throws: AsyncAPIRuntimeError.invalidChannel) {
      try AsyncAPIChannel(
        name: "events",
        address: address,
        parameterNames: ["eventId"]
      )
    }
  }
}

@Test
func closeSignalsStayInsideTheWebSocketControlFrameLimit() throws {
  let signal = try AsyncAPICloseSignal(
    code: .policyViolation,
    reason: "authorization_expired"
  )
  #expect(signal.code.rawValue == 1008)
  #expect(AsyncAPICloseCode(rawValue: 1005) == nil)
  #expect(AsyncAPICloseCode(rawValue: 3999)?.rawValue == 3999)

  let normal = try AsyncAPICloseSignal(code: .normalClosure, reason: "")
  #expect(normal.reason.isEmpty)
  #expect(
    try AsyncAPICloseSignal(
      code: .policyViolation,
      reason: String(repeating: "🦜", count: 30)
    ).reason.utf8.count == 120
  )

  #expect(throws: AsyncAPIRuntimeError.invalidCloseSignal) {
    try AsyncAPICloseSignal(
      code: .policyViolation,
      reason: String(repeating: "x", count: 124)
    )
  }
  #expect(throws: AsyncAPIRuntimeError.invalidCloseSignal) {
    try AsyncAPICloseSignal(
      code: .policyViolation,
      reason: String(repeating: "🦜", count: 31)
    )
  }
}

@Test
func connectionDelegatesTransportOperations() async throws {
  let messages = AsyncThrowingStream<AsyncAPITransportMessage, any Error> {
    continuation in
    continuation.yield(.text("hello"))
    continuation.finish()
  }
  let recorder = Recorder()
  let connection = AsyncAPIConnection(
    applicationContext: FixtureApplicationContext(principal: "user-42"),
    parameters: ["roomId": "room-7"],
    messages: messages,
    send: { await recorder.record(message: $0) },
    close: { await recorder.record(close: $0) }
  )

  #expect(connection.applicationContext.principal == "user-42")
  try await connection.send(.text("world"))
  try await connection.close(
    AsyncAPICloseSignal(code: .goingAway, reason: "reconnect")
  )

  #expect(await recorder.message == .text("world"))
  #expect(await recorder.close?.reason == "reconnect")
}

@Test
func voidConnectionDoesNotRequireExplicitApplicationContext() async throws {
  let messages = AsyncThrowingStream<AsyncAPITransportMessage, any Error> {
    $0.finish()
  }
  let connection: AsyncAPIConnection<Void> = AsyncAPIConnection(
    parameters: [:],
    messages: messages,
    send: { _ in },
    close: { _ in }
  )

  #expect(connection.parameters.isEmpty)
}

@Test
func serverRegistrationBindsTheHandlerApplicationContext() throws {
  let registration = FixtureServerRegistration(handler: FixtureHandler())
  try registration.register(on: FixtureTransport())
}

private struct FixtureApplicationContext: Sendable {
  let principal: String
}

private protocol FixtureAPIProtocol: Sendable {
  associatedtype ApplicationContext: Sendable

  func handle(
    _ connection: AsyncAPIConnection<ApplicationContext>
  ) async throws
}

private struct FixtureHandler: FixtureAPIProtocol {
  func handle(
    _ connection: AsyncAPIConnection<FixtureApplicationContext>
  ) async throws {}
}

private struct FixtureServerRegistration<Handler: FixtureAPIProtocol> {
  let handler: Handler

  func register(
    on transport: some AsyncAPIServerTransport<Handler.ApplicationContext>
  ) throws {
    try transport.register(
      channel: AsyncAPIChannel(
        name: "events",
        address: "/events",
        parameterNames: []
      )
    ) { connection in
      try await handler.handle(connection)
    }
  }
}

private struct FixtureTransport: AsyncAPIServerTransport {
  func register(
    channel: AsyncAPIChannel,
    handler: @escaping AsyncAPIConnectionHandler<FixtureApplicationContext>
  ) throws {}
}

private actor Recorder {
  var message: AsyncAPITransportMessage?
  var close: AsyncAPICloseSignal?

  func record(message: AsyncAPITransportMessage) {
    self.message = message
  }

  func record(close: AsyncAPICloseSignal) {
    self.close = close
  }
}
