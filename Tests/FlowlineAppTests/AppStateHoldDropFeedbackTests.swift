import Testing
@testable import FlowlineApp

@MainActor
@Test func appStateTracksHoldDropTargetAndLandingFeedback() {
  let state = AppState()

  #expect(!state.isHoldDropTargeted)
  #expect(state.holdDropLandingTick == 0)

  state.setHoldDropTargeted(true)
  #expect(state.isHoldDropTargeted)

  state.markHoldDropLanded()
  #expect(!state.isHoldDropTargeted)
  #expect(state.holdDropLandingTick == 1)
}
