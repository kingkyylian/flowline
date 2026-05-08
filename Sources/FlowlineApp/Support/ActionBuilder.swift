import FlowlineCore
import Foundation

enum ActionBuilder {
  static func actions(for snapshot: ContextSnapshot) -> [FlowlineAction] {
    var actions: [FlowlineAction] = []

    if let url = snapshot.nextEvent?.meetingURL {
      actions.append(
        FlowlineAction(
          id: "join-meeting",
          title: "Join",
          systemImage: "video.fill",
          kind: .joinMeeting,
          url: url
        )
      )
    }

    if snapshot.permissions.accessibility != .granted {
      actions.append(
        FlowlineAction(
          id: "accessibility",
          title: "Allow",
          systemImage: "hand.raised.fill",
          kind: .requestPermission
        )
      )
    }

    if !snapshot.shelfItems.isEmpty {
      actions.append(
        FlowlineAction(
          id: "clear-shelf",
          title: "Clear",
          systemImage: "trash",
          kind: .clearShelf
        )
      )
    }

    return actions
  }
}
