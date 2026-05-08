import Foundation

final class AgentProviderService {
  private struct Config: Decodable {
    var providers: [Provider]
  }

  private struct Provider: Decodable {
    var id: String
    var enabled: Bool
  }

  func enabledProviders() -> [String] {
    let url = FileManager.default
      .homeDirectoryForCurrentUser
      .appendingPathComponent(".codexbar/config.json")

    guard let data = try? Data(contentsOf: url),
          let config = try? JSONDecoder().decode(Config.self, from: data) else {
      return ["Codex"]
    }

    let names = config.providers
      .filter(\.enabled)
      .map { label(for: $0.id) }

    return names.isEmpty ? ["Codex"] : names
  }

  private func label(for id: String) -> String {
    switch id {
    case "codex":
      return "Codex"
    case "claude":
      return "Claude"
    case "gemini":
      return "Gemini"
    case "cursor":
      return "Cursor"
    case "opencode":
      return "OpenCode"
    default:
      return id
    }
  }
}
