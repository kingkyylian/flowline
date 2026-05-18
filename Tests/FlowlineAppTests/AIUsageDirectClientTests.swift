import Foundation
import FlowlineCore
import Testing
@testable import FlowlineApp

@Test func geminiProjectResolverUsesExplicitGoogleCloudProjectEnvironment() {
  let project = GeminiProjectResolver.configuredProjectID(
    environment: ["GOOGLE_CLOUD_PROJECT": "real-cloud-project"]
  )

  #expect(project == "real-cloud-project")
}

@Test func geminiUsageClientRefreshesExpiredCredentialsAndFetchesQuota() async throws {
  let home = try temporaryDirectory()
  try writeJSON(
    """
      {
        "expiry_date": 1000,
        "access_token": "stale-token",
        "refresh_token": "refresh-token",
        "token_type": "Bearer"
      }
      """,
    to: home.appendingPathComponent(".gemini/oauth_creds.json")
  )
  let http = RecordingAIUsageHTTPClient(responses: [
    """
      {
        "access_token": "fresh-token",
        "expires_in": 3600,
        "token_type": "Bearer"
      }
      """.data(using: .utf8)!,
    """
      {
        "cloudaicompanionProject": "server-project",
        "currentTier": {
          "id": "free-tier"
        }
      }
      """.data(using: .utf8)!,
    """
      {
        "buckets": [
          {
            "tokenType": "REQUESTS",
            "remainingFraction": 0.42,
            "resetTime": "2026-05-11T15:00:00Z"
          }
        ]
      }
      """.data(using: .utf8)!
  ])
  let client = GeminiUsageClient(
    homeDirectory: home,
    http: http,
    now: { Date(timeIntervalSince1970: 1_778_000_000) }
  )

  let usage = try #require(await client.readUsage()?.usage)

  #expect(usage.provider == .gemini)
  #expect(usage.primary?.percentLeft == 42)
  #expect(http.requests.map { $0.url?.absoluteString } == [
    "https://oauth2.googleapis.com/token",
    "https://cloudcode-pa.googleapis.com/v1internal:loadCodeAssist",
    "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota"
  ])
  #expect(http.requests[1].value(forHTTPHeaderField: "Authorization") == "Bearer fresh-token")
  #expect(http.requests[2].value(forHTTPHeaderField: "Authorization") == "Bearer fresh-token")

  let body = try #require(http.requests[2].httpBody)
  let payload = try #require(JSONSerialization.jsonObject(with: body) as? [String: String])
  #expect(payload["project"] == "server-project")
}

@Test func claudeUsageClientUsesLocalTokenInsteadOfCodexBarCache() async throws {
  let home = try temporaryDirectory()
  let http = RecordingAIUsageHTTPClient(responses: [
    """
      {
        "five_hour": {
          "utilization": 25.0,
          "resets_at": "2026-05-11T15:00:00Z"
        },
        "seven_day": {
          "utilization": 80.0
        }
      }
      """.data(using: .utf8)!
  ])
  let client = ClaudeUsageClient(
    homeDirectory: home,
    environment: ["ANTHROPIC_AUTH_TOKEN": "claude-token"],
    http: http,
    now: { Date(timeIntervalSince1970: 1_778_000_000) }
  )

  let usage = try #require(await client.readUsage()?.usage)

  #expect(usage.provider == .claude)
  #expect(usage.primary?.percentLeft == 75)
  #expect(http.requests.first?.url?.absoluteString == "https://api.anthropic.com/api/oauth/usage")
  #expect(http.requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer claude-token")
}

@Test func agentProviderServiceDiscoversLocalUsageSourcesWithoutCodexBarConfig() throws {
  let home = try temporaryDirectory()
  try writeJSON(
    """
      {
        "access_token": "gemini-token",
        "refresh_token": "refresh-token"
      }
      """,
    to: home.appendingPathComponent(".gemini/oauth_creds.json")
  )

  let service = AgentProviderService(
    homeDirectory: home,
    environment: ["ANTHROPIC_AUTH_TOKEN": "claude-token"]
  )

  #expect(service.enabledProviders() == ["Codex", "Claude", "Gemini"])
}

private final class RecordingAIUsageHTTPClient: AIUsageHTTPClient, @unchecked Sendable {
  private var responses: [Data]
  private(set) var requests: [URLRequest] = []

  init(responses: [Data]) {
    self.responses = responses
  }

  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    requests.append(request)
    let data = responses.removeFirst()
    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil
    )!
    return (data, response)
  }
}

private func temporaryDirectory() throws -> URL {
  let url = FileManager.default.temporaryDirectory
    .appendingPathComponent("FlowlineTests")
    .appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  return url
}

private func writeJSON(_ json: String, to url: URL) throws {
  try FileManager.default.createDirectory(
    at: url.deletingLastPathComponent(),
    withIntermediateDirectories: true
  )
  try json.data(using: .utf8)!.write(to: url)
}
