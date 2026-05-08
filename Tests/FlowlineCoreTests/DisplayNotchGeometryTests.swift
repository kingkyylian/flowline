import CoreGraphics
import Testing
@testable import FlowlineCore

@Test func centersOnCameraHousingGapWhenAuxiliaryAreasExist() throws {
  let centerX = DisplayNotchGeometry.centerX(
    screenFrame: CGRect(x: 0, y: 0, width: 2048, height: 1328),
    auxiliaryTopLeftArea: CGRect(x: 0, y: 1294, width: 534, height: 34),
    auxiliaryTopRightArea: CGRect(x: 860, y: 1294, width: 1188, height: 34)
  )

  #expect(centerX == 697)
}

@Test func buildsCameraHousingFrameWhenAuxiliaryAreasExist() throws {
  let frame = DisplayNotchGeometry.housingFrame(
    screenFrame: CGRect(x: 0, y: 0, width: 1470, height: 956),
    auxiliaryTopLeftArea: CGRect(x: 0, y: 924, width: 646, height: 32),
    auxiliaryTopRightArea: CGRect(x: 825, y: 924, width: 645, height: 32)
  )

  #expect(frame == CGRect(x: 646, y: 924, width: 179, height: 32))
}

@Test func fallsBackToScreenCenterWithoutCameraHousingAreas() throws {
  let centerX = DisplayNotchGeometry.centerX(
    screenFrame: CGRect(x: 100, y: 0, width: 1440, height: 900),
    auxiliaryTopLeftArea: nil,
    auxiliaryTopRightArea: nil
  )

  #expect(centerX == 820)
}

@Test func returnsNilHousingFrameWithoutCameraHousingAreas() throws {
  let frame = DisplayNotchGeometry.housingFrame(
    screenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
    auxiliaryTopLeftArea: nil,
    auxiliaryTopRightArea: nil
  )

  #expect(frame == nil)
}

@Test func detectsCameraHousingWhenAuxiliaryAreasLeaveGap() throws {
  let hasCameraHousing = DisplayNotchGeometry.hasCameraHousing(
    screenFrame: CGRect(x: 0, y: 0, width: 1470, height: 956),
    auxiliaryTopLeftArea: CGRect(x: 0, y: 924, width: 646, height: 32),
    auxiliaryTopRightArea: CGRect(x: 825, y: 924, width: 645, height: 32)
  )

  #expect(hasCameraHousing)
}

@Test func doesNotDetectCameraHousingWithoutAuxiliaryAreas() throws {
  let hasCameraHousing = DisplayNotchGeometry.hasCameraHousing(
    screenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
    auxiliaryTopLeftArea: nil,
    auxiliaryTopRightArea: nil
  )

  #expect(!hasCameraHousing)
}

@Test func fallsBackToScreenCenterWhenAuxiliaryAreasDoNotLeaveAGap() throws {
  let centerX = DisplayNotchGeometry.centerX(
    screenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
    auxiliaryTopLeftArea: CGRect(x: 0, y: 866, width: 720, height: 34),
    auxiliaryTopRightArea: CGRect(x: 720, y: 866, width: 720, height: 34)
  )

  #expect(centerX == 720)
}
