enum HoldDropImportRoute: Equatable, Sendable {
  case filePromise
  case fileURL
  case webURL
  case imageData
  case text
}

enum HoldDropImportPlan {
  static func route(
    hasFilePromise: Bool,
    hasFileURL: Bool,
    hasWebURL: Bool,
    hasImageData: Bool,
    hasText: Bool
  ) -> HoldDropImportRoute? {
    if hasFilePromise {
      return .filePromise
    }

    if hasFileURL {
      return .fileURL
    }

    if hasWebURL {
      return .webURL
    }

    if hasImageData {
      return .imageData
    }

    if hasText {
      return .text
    }

    return nil
  }
}
