public typealias AsyncAPIConnectionHandler<ApplicationContext: Sendable> =
  @Sendable (AsyncAPIConnection<ApplicationContext>) async throws -> Void

public protocol AsyncAPIServerTransport<ApplicationContext>: Sendable {
  associatedtype ApplicationContext: Sendable = Void

  func register(
    channel: AsyncAPIChannel,
    handler: @escaping AsyncAPIConnectionHandler<ApplicationContext>
  ) throws
}
