import Foundation

final class AgentProviderService {
  private let homeDirectory: URL
  private let environment: [String: String]

  init(
    homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) {
    self.homeDirectory = homeDirectory
    self.environment = environment
  }

  func enabledProviders() -> [String] {
    var providers = ["Codex"]

    if ClaudeUsageCredentialResolver.hasCredential(
      homeDirectory: homeDirectory,
      environment: environment
    ) {
      providers.append("Claude")
    }

    if GeminiUsageClient.hasCredentials(homeDirectory: homeDirectory) {
      providers.append("Gemini")
    }

    return providers
  }
}
