import Flutter
import UIKit
import CoreLocation
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  func testLocationStoreBackupExclusionSurvivesAtomicWrites() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let directory = root.appendingPathComponent(
      LocationStoreBackupExclusion.directoryName,
      isDirectory: true
    )
    let file = directory.appendingPathComponent(
      LocationStoreBackupExclusion.fileName
    )
    defer { try? FileManager.default.removeItem(at: root) }

    try LocationStoreBackupExclusion.ensureExcluded(
      directoryURL: directory,
      fileURL: file
    )
    try Data("first".utf8).write(to: file, options: .atomic)
    try LocationStoreBackupExclusion.ensureExcluded(
      directoryURL: directory,
      fileURL: file
    )

    XCTAssertTrue(
      try directory.resourceValues(forKeys: [.isExcludedFromBackupKey])
        .isExcludedFromBackup == true
    )
    XCTAssertTrue(
      try file.resourceValues(forKeys: [.isExcludedFromBackupKey])
        .isExcludedFromBackup == true
    )

    try Data("replacement".utf8).write(to: file, options: .atomic)
    try LocationStoreBackupExclusion.ensureExcluded(
      directoryURL: directory,
      fileURL: file
    )
    XCTAssertTrue(
      try directory.resourceValues(forKeys: [.isExcludedFromBackupKey])
        .isExcludedFromBackup == true
    )
    XCTAssertTrue(
      try file.resourceValues(forKeys: [.isExcludedFromBackupKey])
        .isExcludedFromBackup == true
    )
  }

  func testExample() {
    // If you add code to the Runner application, consider adding tests here.
    // See https://developer.apple.com/documentation/xctest for more information about using XCTest.
  }

  func testPositiveAndNegativeDeclinationRotateMagneticNorthInTheCorrectDirection() {
    let positive = magneticEnuToTrue((0, 1, 0), declinationDegrees: 12)
    let negative = magneticEnuToTrue((0, 1, 0), declinationDegrees: -12)

    XCTAssertGreaterThan(positive.0, 0)
    XCTAssertLessThan(negative.0, 0)
    XCTAssertEqual(positive.0, sin(12 * .pi / 180), accuracy: 1e-12)
    XCTAssertEqual(positive.1, cos(12 * .pi / 180), accuracy: 1e-12)
    XCTAssertEqual(negative.0, sin(-12 * .pi / 180), accuracy: 1e-12)
    XCTAssertEqual(negative.1, cos(-12 * .pi / 180), accuracy: 1e-12)
  }

  func testHeadingWraparoundProducesSignedDeclination() {
    XCTAssertEqual(signedAngleDifference(359, 1), 2, accuracy: 1e-12)
    XCTAssertEqual(signedAngleDifference(1, 359), -2, accuracy: 1e-12)
  }

  func testDeclinationRotationPreservesDeviceAxesInPortraitAndLandscape() {
    let orientations: [[(Double, Double, Double)]] = [
      [(1, 0, 0), (0, 1, 0), (0, 0, 1)],
      [(0, 1, 0), (-1, 0, 0), (0, 0, 1)],
      [(-1, 0, 0), (0, -1, 0), (0, 0, 1)],
      [(0, -1, 0), (1, 0, 0), (0, 0, 1)],
    ]

    for axes in orientations {
      let transformed = axes.map {
        magneticEnuToTrue($0, declinationDegrees: -17)
      }
      for vector in transformed {
        XCTAssertEqual(
          vector.0 * vector.0 + vector.1 * vector.1 + vector.2 * vector.2,
          1,
          accuracy: 1e-12
        )
      }
      XCTAssertEqual(
        transformed[0].0 * transformed[1].0 +
          transformed[0].1 * transformed[1].1 +
          transformed[0].2 * transformed[1].2,
        0,
        accuracy: 1e-12
      )
      XCTAssertEqual(transformed[0].2, axes[0].2, accuracy: 1e-12)
    }
  }

  func testFreshLocationAndHeadingSamplesProduceDeclination() {
    XCTAssertEqual(
      checkedCorrection(),
      .magnetic(declinationDegrees: 8)
    )
  }

  func testSamplesJustYoungerThanTwoMinutesRemainFresh() {
    let sampleTime = testNow.addingTimeInterval(
      -magneticNorthSampleMaximumAge + 0.001
    )
    XCTAssertEqual(
      checkedCorrection(
        location: locationSample(at: sampleTime),
        heading: headingSample(at: sampleTime)
      ),
      .magnetic(declinationDegrees: 8)
    )
  }

  func testSamplesExpireAtTheTwoMinuteBoundary() {
    let sampleTime = testNow.addingTimeInterval(
      -magneticNorthSampleMaximumAge
    )
    XCTAssertEqual(
      checkedCorrection(
        location: locationSample(at: sampleTime),
        heading: headingSample(at: sampleTime)
      ),
      .unavailable
    )
  }

  func testOlderSamplesAreUnavailableWhenMotionContinuesWithoutLocationUpdates() {
    XCTAssertEqual(
      checkedCorrection(now: testNow.addingTimeInterval(120.001)),
      .unavailable
    )
  }

  func testFreshHeadingCannotReuseAnExpiredLocationSample() {
    let expired = testNow.addingTimeInterval(-120.001)
    XCTAssertEqual(
      checkedCorrection(location: locationSample(at: expired)),
      .unavailable
    )
  }

  func testFreshLocationCannotReuseAnExpiredHeadingSample() {
    let expired = testNow.addingTimeInterval(-120.001)
    XCTAssertEqual(
      checkedCorrection(heading: headingSample(at: expired)),
      .unavailable
    )
  }

  func testBackgroundResumeInvalidatesOldSamplesAndRestoresWithFreshSamples() {
    let resumedAt = testNow.addingTimeInterval(300)
    XCTAssertEqual(checkedCorrection(now: resumedAt), .unavailable)
    XCTAssertEqual(
      checkedCorrection(
        location: locationSample(at: resumedAt),
        heading: headingSample(at: resumedAt),
        now: resumedAt
      ),
      .magnetic(declinationDegrees: 8)
    )
  }

  func testFutureDatedSamplesAreUnavailable() {
    let future = testNow.addingTimeInterval(1)
    XCTAssertEqual(
      checkedCorrection(location: locationSample(at: future)),
      .unavailable
    )
    XCTAssertEqual(
      checkedCorrection(heading: headingSample(at: future)),
      .unavailable
    )
  }

  func testInvalidHeadingAccuracyAndHeadingValuesAreUnavailable() {
    for accuracy in [-1.0, .nan, .infinity, 180.001] {
      XCTAssertEqual(
        checkedCorrection(
          heading: MagneticHeadingSample(
            magneticHeadingDegrees: 7,
            trueHeadingDegrees: 15,
            accuracyDegrees: accuracy,
            timestamp: testNow
          )
        ),
        .unavailable
      )
    }

    for magneticHeading in [-1.0, 360, .nan, .infinity] {
      XCTAssertEqual(
        checkedCorrection(
          heading: MagneticHeadingSample(
            magneticHeadingDegrees: magneticHeading,
            trueHeadingDegrees: 15,
            accuracyDegrees: 1,
            timestamp: testNow
          )
        ),
        .unavailable
      )
    }

    for trueHeading in [-1.0, 360, .nan, .infinity] {
      XCTAssertEqual(
        checkedCorrection(
          heading: MagneticHeadingSample(
            magneticHeadingDegrees: 7,
            trueHeadingDegrees: trueHeading,
            accuracyDegrees: 1,
            timestamp: testNow
          )
        ),
        .unavailable
      )
    }
  }

  func testMissingOrInvalidLocationIsUnavailable() {
    XCTAssertEqual(checkedCorrection(location: nil), .unavailable)
    XCTAssertEqual(checkedCorrection(observer: nil), .unavailable)
    XCTAssertEqual(
      checkedCorrection(
        location: MagneticLocationSample(
          coordinate: CLLocationCoordinate2D(latitude: .nan, longitude: 0),
          horizontalAccuracyMeters: 10,
          timestamp: testNow
        )
      ),
      .unavailable
    )
    for accuracy in [-1.0, .nan, .infinity] {
      XCTAssertEqual(
        checkedCorrection(
          location: MagneticLocationSample(
            coordinate: observerCoordinate,
            horizontalAccuracyMeters: accuracy,
            timestamp: testNow
          )
        ),
        .unavailable
      )
    }
  }

  func testRevokedPermissionUnavailableHeadingAndRemoteObserverAreRejected() {
    XCTAssertEqual(
      checkedCorrection(authorizationStatus: .denied),
      .unavailable
    )
    XCTAssertEqual(checkedCorrection(headingAvailable: false), .unavailable)
    XCTAssertEqual(
      checkedCorrection(
        observer: CLLocationCoordinate2D(latitude: 40, longitude: -74)
      ),
      .unavailable
    )
  }

  func testTrueNorthDoesNotDependOnLocationSamplesOrPermission() {
    XCTAssertEqual(
      checkedCorrection(
        usesTrueNorth: true,
        observer: nil,
        location: nil,
        heading: nil,
        authorizationStatus: .denied,
        headingAvailable: false
      ),
      .trueNorth
    )
  }

}

private let testNow = Date(timeIntervalSince1970: 1_700_000_000)
private let observerCoordinate = CLLocationCoordinate2D(
  latitude: 37.3349,
  longitude: -122.0090
)

private func locationSample(at timestamp: Date) -> MagneticLocationSample {
  MagneticLocationSample(
    coordinate: observerCoordinate,
    horizontalAccuracyMeters: 15,
    timestamp: timestamp
  )
}

private func headingSample(at timestamp: Date) -> MagneticHeadingSample {
  MagneticHeadingSample(
    magneticHeadingDegrees: 7,
    trueHeadingDegrees: 15,
    accuracyDegrees: 1,
    timestamp: timestamp
  )
}

private func checkedCorrection(
  usesTrueNorth: Bool = false,
  observer: CLLocationCoordinate2D? = observerCoordinate,
  location: MagneticLocationSample? = locationSample(at: testNow),
  heading: MagneticHeadingSample? = headingSample(at: testNow),
  authorizationStatus: CLAuthorizationStatus = .authorizedWhenInUse,
  headingAvailable: Bool = true,
  now: Date = testNow
) -> OrientationNorthCorrection {
  northCorrectionForPublication(
    usesTrueNorth: usesTrueNorth,
    observerLocation: observer,
    location: location,
    heading: heading,
    authorizationStatus: authorizationStatus,
    headingAvailable: headingAvailable,
    now: now
  )
}
