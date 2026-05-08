import CoreGraphics

public enum DisplayNotchGeometry {
  public static func hasCameraHousing(
    screenFrame: CGRect,
    auxiliaryTopLeftArea: CGRect?,
    auxiliaryTopRightArea: CGRect?
  ) -> Bool {
    housingFrame(
      screenFrame: screenFrame,
      auxiliaryTopLeftArea: auxiliaryTopLeftArea,
      auxiliaryTopRightArea: auxiliaryTopRightArea
    ) != nil
  }

  public static func centerX(
    screenFrame: CGRect,
    auxiliaryTopLeftArea: CGRect?,
    auxiliaryTopRightArea: CGRect?
  ) -> CGFloat {
    guard
      let auxiliaryTopLeftArea,
      let auxiliaryTopRightArea,
      auxiliaryTopLeftArea.maxX < auxiliaryTopRightArea.minX
    else {
      return screenFrame.midX
    }

    return (auxiliaryTopLeftArea.maxX + auxiliaryTopRightArea.minX) / 2
  }

  public static func housingFrame(
    screenFrame: CGRect,
    auxiliaryTopLeftArea: CGRect?,
    auxiliaryTopRightArea: CGRect?
  ) -> CGRect? {
    guard
      let auxiliaryTopLeftArea,
      let auxiliaryTopRightArea,
      auxiliaryTopLeftArea.maxX < auxiliaryTopRightArea.minX
    else {
      return nil
    }

    return CGRect(
      x: auxiliaryTopLeftArea.maxX,
      y: min(auxiliaryTopLeftArea.minY, auxiliaryTopRightArea.minY),
      width: auxiliaryTopRightArea.minX - auxiliaryTopLeftArea.maxX,
      height: min(auxiliaryTopLeftArea.height, auxiliaryTopRightArea.height)
    )
  }
}
