import FlowlineCore

actor MusicPlaybackRefreshWorker {
  private var controllers: [any MusicPlayerControlling]
  private var activeController: (any MusicPlayerControlling)?

  init(
    controllers: [any MusicPlayerControlling] = MusicPlaybackSource.allCases.map {
      AppleScriptMusicPlayerController(source: $0)
    }
  ) {
    self.controllers = controllers
  }

  func refresh() -> MusicPlaybackSnapshot? {
    for controller in controllers {
      guard controller.isRunning() else {
        continue
      }

      activeController = controller
      return controller.playbackSnapshot()
    }

    activeController = nil
    return nil
  }

  func run(command: MusicPlayerCommand) -> Bool {
    if let activeController, activeController.isRunning() {
      return activeController.run(command: command)
    }

    for controller in controllers {
      guard controller.isRunning() else {
        continue
      }

      activeController = controller
      return controller.run(command: command)
    }

    activeController = nil
    return false
  }

  func replaceControllersForTesting(_ controllers: [any MusicPlayerControlling]) {
    self.controllers = controllers
  }
}
