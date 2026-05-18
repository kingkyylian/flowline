import FlowlineCore
import Foundation

protocol AIUsageHTTPClient: Sendable {
  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionAIUsageHTTPClient: AIUsageHTTPClient {
  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw AIUsageRequestError.invalidResponse
    }
    guard (200..<300).contains(httpResponse.statusCode) else {
      throw AIUsageRequestError.httpStatus(httpResponse.statusCode)
    }
    return (data, httpResponse)
  }
}

struct TimedProviderUsage {
  var usage: AIProviderUsage
  var recordedAt: Date
}

struct AIUsageDirectReader {
  var homeDirectory: URL
  var environment: [String: String]
  var http: any AIUsageHTTPClient
  var now: @Sendable () -> Date

  init(
    homeDirectory: URL,
    environment: [String: String] = ProcessInfo.processInfo.environment,
    http: any AIUsageHTTPClient = URLSessionAIUsageHTTPClient(),
    now: @escaping @Sendable () -> Date = Date.init
  ) {
    self.homeDirectory = homeDirectory
    self.environment = environment
    self.http = http
    self.now = now
  }

  func readProviders() async -> [TimedProviderUsage] {
    async let claude = ClaudeUsageClient(
      homeDirectory: homeDirectory,
      environment: environment,
      http: http,
      now: now
    ).readUsage()
    async let gemini = GeminiUsageClient(
      homeDirectory: homeDirectory,
      environment: environment,
      http: http,
      now: now
    ).readUsage()

    let claudeUsage = await claude
    let geminiUsage = await gemini
    return [claudeUsage, geminiUsage].compactMap { $0 }
  }
}

struct ClaudeUsageClient {
  var homeDirectory: URL
  var environment: [String: String]
  var http: any AIUsageHTTPClient
  var now: @Sendable () -> Date

  init(
    homeDirectory: URL,
    environment: [String: String] = ProcessInfo.processInfo.environment,
    http: any AIUsageHTTPClient = URLSessionAIUsageHTTPClient(),
    now: @escaping @Sendable () -> Date = Date.init
  ) {
    self.homeDirectory = homeDirectory
    self.environment = environment
    self.http = http
    self.now = now
  }

  func readUsage() async -> TimedProviderUsage? {
    guard let token = ClaudeUsageCredentialResolver.token(
      homeDirectory: homeDirectory,
      environment: environment
    ) else {
      return nil
    }

    do {
      let request = Self.usageRequest(accessToken: token)
      let (data, _) = try await http.data(for: request)
      let usage = try ClaudeUsageParser.parse(data)
      return TimedProviderUsage(usage: usage, recordedAt: now())
    } catch {
      return nil
    }
  }

  static func usageRequest(accessToken: String) -> URLRequest {
    var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
    request.httpMethod = "GET"
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    return request
  }
}

enum ClaudeUsageCredentialResolver {
  private static let environmentKeys = [
    "ANTHROPIC_AUTH_TOKEN",
    "CLAUDE_CODE_OAUTH_TOKEN",
    "CLAUDE_OAUTH_TOKEN"
  ]
  private static let credentialRelativePaths = [
    ".claude/.credentials.json",
    ".claude/oauth_creds.json",
    ".claude/auth.json"
  ]
  private static let tokenKeys = [
    "access_token",
    "oauth_token",
    "auth_token",
    "authToken",
    "token"
  ]

  static func hasCredential(
    homeDirectory: URL,
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> Bool {
    token(homeDirectory: homeDirectory, environment: environment) != nil
  }

  static func token(
    homeDirectory: URL,
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> String? {
    for key in environmentKeys {
      if let value = nonEmpty(environment[key]) {
        return value
      }
    }

    for relativePath in credentialRelativePaths {
      let url = homeDirectory.appendingPathComponent(relativePath)
      guard
        let data = try? Data(contentsOf: url),
        let object = try? JSONSerialization.jsonObject(with: data),
        let token = token(in: object)
      else {
        continue
      }
      return token
    }

    return nil
  }

  private static func token(in object: Any) -> String? {
    if let dictionary = object as? [String: Any] {
      for key in tokenKeys {
        if let token = nonEmpty(dictionary[key] as? String) {
          return token
        }
      }

      for value in dictionary.values {
        if let token = token(in: value) {
          return token
        }
      }
    } else if let array = object as? [Any] {
      for value in array {
        if let token = token(in: value) {
          return token
        }
      }
    }

    return nil
  }

  private static func nonEmpty(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
      return nil
    }
    return value
  }
}

struct GeminiUsageClient {
  var homeDirectory: URL
  var environment: [String: String]
  var http: any AIUsageHTTPClient
  var now: @Sendable () -> Date

  init(
    homeDirectory: URL,
    environment: [String: String] = ProcessInfo.processInfo.environment,
    http: any AIUsageHTTPClient = URLSessionAIUsageHTTPClient(),
    now: @escaping @Sendable () -> Date = Date.init
  ) {
    self.homeDirectory = homeDirectory
    self.environment = environment
    self.http = http
    self.now = now
  }

  func readUsage() async -> TimedProviderUsage? {
    guard let accessToken = await accessToken() else {
      return nil
    }

    let configuredProjectID = GeminiProjectResolver.configuredProjectID(environment: environment)
    let projectID: String?
    if let configuredProjectID {
      projectID = configuredProjectID
    } else {
      projectID = await loadCodeAssistProjectID(accessToken: accessToken, configuredProjectID: nil)
    }

    guard let projectID else {
      return nil
    }

    do {
      let request = try Self.quotaRequest(projectID: projectID, accessToken: accessToken)
      let (data, _) = try await http.data(for: request)
      let usage = try GeminiUsageParser.parse(data)
      return TimedProviderUsage(usage: usage, recordedAt: now())
    } catch {
      return nil
    }
  }

  private func loadCodeAssistProjectID(
    accessToken: String,
    configuredProjectID: String?
  ) async -> String? {
    do {
      let request = try Self.loadCodeAssistRequest(
        accessToken: accessToken,
        projectID: configuredProjectID
      )
      let (data, _) = try await http.data(for: request)
      let response = try JSONDecoder().decode(GeminiLoadCodeAssistResponse.self, from: data)
      return response.cloudaicompanionProject ?? configuredProjectID
    } catch {
      return configuredProjectID
    }
  }

  static func hasCredentials(homeDirectory: URL) -> Bool {
    FileManager.default.fileExists(atPath: credentialsURL(homeDirectory: homeDirectory).path)
  }

  static func credentialsURL(homeDirectory: URL) -> URL {
    homeDirectory.appendingPathComponent(".gemini/oauth_creds.json")
  }

  private func accessToken() async -> String? {
    let credentialsURL = Self.credentialsURL(homeDirectory: homeDirectory)
    guard
      let data = try? Data(contentsOf: credentialsURL),
      var credentials = try? JSONDecoder().decode(GeminiOAuthCredentials.self, from: data)
    else {
      return nil
    }

    if let token = credentials.validAccessToken(now: now()) {
      return token
    }

    guard let refreshToken = credentials.refreshToken else {
      return nil
    }

    do {
      let request = Self.tokenRefreshRequest(refreshToken: refreshToken)
      let (data, _) = try await http.data(for: request)
      let response = try JSONDecoder().decode(GeminiOAuthRefreshResponse.self, from: data)

      credentials.accessToken = response.accessToken
      credentials.idToken = response.idToken ?? credentials.idToken
      credentials.scope = response.scope ?? credentials.scope
      credentials.tokenType = response.tokenType ?? credentials.tokenType
      credentials.refreshToken = response.refreshToken ?? credentials.refreshToken
      credentials.expiryDate = now()
        .addingTimeInterval(TimeInterval(response.expiresIn ?? 3600))
        .timeIntervalSince1970 * 1000

      let encoded = try JSONEncoder().encode(credentials)
      try encoded.write(to: credentialsURL, options: .atomic)
      return response.accessToken
    } catch {
      return nil
    }
  }

  static func tokenRefreshRequest(refreshToken: String) -> URLRequest {
    var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    let fields = [
      "client_id": "GEMINI_OAUTH_CLIENT_ID_REQUIRED",
      "client_secret": "GEMINI_OAUTH_CLIENT_SECRET_REQUIRED",
      "refresh_token": refreshToken,
      "grant_type": "refresh_token"
    ]
    request.httpBody = fields
      .map { "\($0.key)=\(Self.formEncoded($0.value))" }
      .joined(separator: "&")
      .data(using: .utf8)
    return request
  }

  static func quotaRequest(projectID: String, accessToken: String) throws -> URLRequest {
    var request = URLRequest(url: URL(string: "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota")!)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONEncoder().encode(GeminiQuotaRequest(project: projectID))
    return request
  }

  static func loadCodeAssistRequest(accessToken: String, projectID: String?) throws -> URLRequest {
    var request = URLRequest(url: URL(string: "https://cloudcode-pa.googleapis.com/v1internal:loadCodeAssist")!)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONEncoder().encode(GeminiLoadCodeAssistRequest(projectID: projectID))
    return request
  }

  private static func formEncoded(_ value: String) -> String {
    var allowed = CharacterSet.urlQueryAllowed
    allowed.remove(charactersIn: "&+=")
    return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
  }
}

enum GeminiProjectResolver {
  static func configuredProjectID(
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> String? {
    for key in ["GOOGLE_CLOUD_PROJECT", "GOOGLE_CLOUD_PROJECT_ID", "GCLOUD_PROJECT"] {
      if let value = nonEmpty(environment[key]) {
        return value
      }
    }

    return nil
  }

  private static func nonEmpty(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
      return nil
    }
    return value
  }
}

private enum AIUsageRequestError: Error {
  case invalidResponse
  case httpStatus(Int)
}

private struct GeminiOAuthCredentials: Codable {
  var expiryDate: Double?
  var accessToken: String?
  var idToken: String?
  var refreshToken: String?
  var scope: String?
  var tokenType: String?

  enum CodingKeys: String, CodingKey {
    case expiryDate = "expiry_date"
    case accessToken = "access_token"
    case idToken = "id_token"
    case refreshToken = "refresh_token"
    case scope
    case tokenType = "token_type"
  }

  func validAccessToken(now: Date) -> String? {
    guard
      let accessToken,
      !accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      let expiryDate,
      expiryDate / 1000 > now.addingTimeInterval(60).timeIntervalSince1970
    else {
      return nil
    }
    return accessToken
  }
}

private struct GeminiOAuthRefreshResponse: Decodable {
  var accessToken: String
  var expiresIn: Int?
  var idToken: String?
  var refreshToken: String?
  var scope: String?
  var tokenType: String?

  enum CodingKeys: String, CodingKey {
    case accessToken = "access_token"
    case expiresIn = "expires_in"
    case idToken = "id_token"
    case refreshToken = "refresh_token"
    case scope
    case tokenType = "token_type"
  }
}

private struct GeminiLoadCodeAssistRequest: Encodable {
  var cloudaicompanionProject: String?
  var metadata: GeminiLoadCodeAssistMetadata

  init(projectID: String?) {
    self.cloudaicompanionProject = projectID
    self.metadata = GeminiLoadCodeAssistMetadata(duetProject: projectID)
  }
}

private struct GeminiLoadCodeAssistMetadata: Encodable {
  var ideType = "IDE_UNSPECIFIED"
  var platform = "PLATFORM_UNSPECIFIED"
  var pluginType = "GEMINI"
  var duetProject: String?
}

private struct GeminiLoadCodeAssistResponse: Decodable {
  var cloudaicompanionProject: String?
}

private struct GeminiQuotaRequest: Encodable {
  var project: String
}
