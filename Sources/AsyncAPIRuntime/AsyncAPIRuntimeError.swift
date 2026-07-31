public enum AsyncAPIRuntimeError: Error, Equatable, Sendable {
  case invalidChannel
  case invalidCloseSignal
  case missingChannelParameter(String)
  case unsupportedMessage
}
