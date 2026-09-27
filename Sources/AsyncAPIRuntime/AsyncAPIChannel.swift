public struct AsyncAPIChannel: Hashable, Sendable {
  public let name: String
  public let address: String
  public let parameterNames: [String]

  public init(
    name: String,
    address: String,
    parameterNames: [String]
  ) throws {
    let addressParameterNames = try Self.parseParameterNames(in: address)
    guard !name.isEmpty,
      address.first == "/",
      Set(parameterNames).count == parameterNames.count,
      parameterNames == addressParameterNames
    else {
      throw AsyncAPIRuntimeError.invalidChannel
    }
    self.name = name
    self.address = address
    self.parameterNames = parameterNames
  }

  private static func parseParameterNames(in address: String) throws -> [String] {
    if address == "/" { return [] }
    var names: [String] = []
    let segments = address.split(separator: "/", omittingEmptySubsequences: false)
    guard segments.first?.isEmpty == true,
      segments.dropFirst().allSatisfy({ !$0.isEmpty })
    else {
      throw AsyncAPIRuntimeError.invalidChannel
    }
    for segment in segments.dropFirst() {
      if segment.first == "{" || segment.last == "}" {
        guard segment.first == "{", segment.last == "}",
          !segment.dropFirst().dropLast().contains("{"),
          !segment.dropFirst().dropLast().contains("}")
        else {
          throw AsyncAPIRuntimeError.invalidChannel
        }
        let name = segment.dropFirst().dropLast()
        guard Self.isParameterName(name) else {
          throw AsyncAPIRuntimeError.invalidChannel
        }
        names.append(String(name))
      } else {
        guard segment != ".", segment != "..",
          segment.utf8.allSatisfy(Self.isUnreservedPathByte)
        else {
          throw AsyncAPIRuntimeError.invalidChannel
        }
      }
    }
    return names
  }

  private static func isParameterName(_ value: Substring) -> Bool {
    guard let first = value.utf8.first,
      Self.isASCIIAlpha(first) || first == 0x5F
    else {
      return false
    }
    return value.utf8.dropFirst().allSatisfy {
      Self.isASCIIAlpha($0) || (0x30...0x39).contains($0) || $0 == 0x5F
    }
  }

  private static func isASCIIAlpha(_ value: UInt8) -> Bool {
    (0x41...0x5A).contains(value) || (0x61...0x7A).contains(value)
  }

  private static func isUnreservedPathByte(_ value: UInt8) -> Bool {
    isASCIIAlpha(value) || (0x30...0x39).contains(value)
      || value == 0x2D || value == 0x2E || value == 0x5F || value == 0x7E
  }
}
