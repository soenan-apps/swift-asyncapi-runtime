public enum AsyncAPITransportMessage: Equatable, Sendable {
  case text(String)
  case binary([UInt8])
}

public struct AsyncAPICloseCode: Equatable, Hashable, RawRepresentable, Sendable {
  public static let normalClosure = Self(uncheckedRawValue: 1000)
  public static let goingAway = Self(uncheckedRawValue: 1001)
  public static let protocolError = Self(uncheckedRawValue: 1002)
  public static let unsupportedData = Self(uncheckedRawValue: 1003)
  public static let invalidFramePayloadData = Self(uncheckedRawValue: 1007)
  public static let policyViolation = Self(uncheckedRawValue: 1008)
  public static let messageTooBig = Self(uncheckedRawValue: 1009)
  public static let mandatoryExtension = Self(uncheckedRawValue: 1010)
  public static let internalError = Self(uncheckedRawValue: 1011)
  public static let serviceRestart = Self(uncheckedRawValue: 1012)
  public static let tryAgainLater = Self(uncheckedRawValue: 1013)
  public static let badGateway = Self(uncheckedRawValue: 1014)

  public let rawValue: UInt16

  public init?(rawValue: UInt16) {
    guard Self.isValidWireCode(rawValue) else { return nil }
    self.rawValue = rawValue
  }

  private init(uncheckedRawValue: UInt16) {
    self.rawValue = uncheckedRawValue
  }

  private static func isValidWireCode(_ value: UInt16) -> Bool {
    switch value {
    case 1000...1003, 1007...1014, 3000...4999:
      true
    default:
      false
    }
  }
}

public struct AsyncAPICloseSignal: Equatable, Sendable {
  public let code: AsyncAPICloseCode
  public let reason: String

  public init(code: AsyncAPICloseCode, reason: String) throws {
    guard reason.utf8.count <= 123 else {
      throw AsyncAPIRuntimeError.invalidCloseSignal
    }
    self.code = code
    self.reason = reason
  }
}

public struct AsyncAPIConnection<ApplicationContext: Sendable>: Sendable {
  public let applicationContext: ApplicationContext
  public let parameters: [String: String]
  public let messages: AsyncThrowingStream<AsyncAPITransportMessage, any Error>

  private let sendOperation: @Sendable (AsyncAPITransportMessage) async throws -> Void
  private let closeOperation: @Sendable (AsyncAPICloseSignal) async throws -> Void

  public init(
    applicationContext: ApplicationContext,
    parameters: [String: String],
    messages: AsyncThrowingStream<AsyncAPITransportMessage, any Error>,
    send: @escaping @Sendable (AsyncAPITransportMessage) async throws -> Void,
    close: @escaping @Sendable (AsyncAPICloseSignal) async throws -> Void
  ) {
    self.applicationContext = applicationContext
    self.parameters = parameters
    self.messages = messages
    self.sendOperation = send
    self.closeOperation = close
  }

  public func send(_ message: AsyncAPITransportMessage) async throws {
    try await sendOperation(message)
  }

  public func close(_ signal: AsyncAPICloseSignal) async throws {
    try await closeOperation(signal)
  }
}

extension AsyncAPIConnection where ApplicationContext == Void {
  public init(
    parameters: [String: String],
    messages: AsyncThrowingStream<AsyncAPITransportMessage, any Error>,
    send: @escaping @Sendable (AsyncAPITransportMessage) async throws -> Void,
    close: @escaping @Sendable (AsyncAPICloseSignal) async throws -> Void
  ) {
    self.init(
      applicationContext: (),
      parameters: parameters,
      messages: messages,
      send: send,
      close: close
    )
  }
}
