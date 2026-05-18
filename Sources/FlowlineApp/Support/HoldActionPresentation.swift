import FlowlineCore

struct HoldActionPresentation {
  enum Kind: Hashable, Sendable {
    case copy
    case copyOCR
    case next
    case delete
  }

  struct Action: Identifiable, Equatable, Sendable {
    let kind: Kind
    let label: String
    let title: String
    let systemImage: String
    let isDestructive: Bool

    var id: Kind {
      kind
    }
  }

  static func actions(for item: ShelfItem, itemCount: Int) -> [Action] {
    var actions = [primaryAction(for: item)]

    if itemCount > 1 {
      actions.append(nextAction)
    } else if item.kind == .screenshot, hasOCRText(item) {
      actions.append(ocrAction)
    }

    actions.append(deleteAction)
    return actions
  }

  private static func primaryAction(for item: ShelfItem) -> Action {
    switch item.kind {
    case .file:
      Action(
        kind: .copy,
        label: "PATH",
        title: "Copy terminal path for current hold item",
        systemImage: "terminal",
        isDestructive: false
      )
    case .screenshot:
      Action(
        kind: .copy,
        label: "IMG",
        title: "Copy screenshot image",
        systemImage: "photo",
        isDestructive: false
      )
    case .text, .code, .link, .sensitive:
      Action(
        kind: .copy,
        label: "COPY",
        title: "Copy current hold item",
        systemImage: "doc.on.doc",
        isDestructive: false
      )
    }
  }

  private static func hasOCRText(_ item: ShelfItem) -> Bool {
    guard let text = item.ocrText?.trimmingCharacters(in: .whitespacesAndNewlines) else {
      return false
    }

    return !text.isEmpty
  }

  private static var ocrAction: Action {
    Action(
      kind: .copyOCR,
      label: "TEXT",
      title: "Copy screenshot OCR text",
      systemImage: "text.viewfinder",
      isDestructive: false
    )
  }

  private static var nextAction: Action {
    Action(
      kind: .next,
      label: "NEXT",
      title: "Show next hold item",
      systemImage: "arrow.triangle.2.circlepath",
      isDestructive: false
    )
  }

  private static var deleteAction: Action {
    Action(
      kind: .delete,
      label: "DEL",
      title: "Delete current hold item",
      systemImage: "minus.circle",
      isDestructive: true
    )
  }
}
