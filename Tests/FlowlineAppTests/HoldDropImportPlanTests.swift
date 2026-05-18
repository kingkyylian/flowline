import Testing
@testable import FlowlineApp

@Test func holdDropImportUsesOnlyOneRouteForRichScreenshotPasteboards() {
  let route = HoldDropImportPlan.route(
    hasFilePromise: true,
    hasFileURL: true,
    hasWebURL: false,
    hasImageData: true,
    hasText: true
  )

  #expect(route == .filePromise)
}

@Test func holdDropImportPrefersImageDataOverFallbackText() {
  let route = HoldDropImportPlan.route(
    hasFilePromise: false,
    hasFileURL: false,
    hasWebURL: false,
    hasImageData: true,
    hasText: true
  )

  #expect(route == .imageData)
}

@Test func holdDropImportKeepsWebURLAbovePlainText() {
  let route = HoldDropImportPlan.route(
    hasFilePromise: false,
    hasFileURL: false,
    hasWebURL: true,
    hasImageData: false,
    hasText: true
  )

  #expect(route == .webURL)
}
