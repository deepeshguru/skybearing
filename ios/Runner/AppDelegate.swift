import Flutter
import UIKit
import CoreMotion
import CoreLocation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "OfflineSkyOrientationPlugin")
    let messenger = registrar.messenger()
    let motionHandler = OfflineSkyMotionStreamHandler()
    let methodChannel = FlutterMethodChannel(
      name: "com.offlinesky.sky/orientation",
      binaryMessenger: messenger
    )
    methodChannel.setMethodCallHandler { call, result in
      if call.method == "setObserverLocation" {
        guard
          let arguments = call.arguments as? [String: Any],
          let latitude = arguments["latitude"] as? Double,
          let longitude = arguments["longitude"] as? Double,
          CLLocationCoordinate2DIsValid(
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
          )
        else {
          result(FlutterError(
            code: "invalid_observer_location",
            message: "A valid observer latitude and longitude are required.",
            details: nil
          ))
          return
        }
        motionHandler.setObserverLocation(latitude: latitude, longitude: longitude)
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    let locationBackupChannel = FlutterMethodChannel(
      name: "com.offlinesky.sky/location_backup",
      binaryMessenger: messenger
    )
    locationBackupChannel.setMethodCallHandler { call, result in
      guard call.method == "excludeLocationStore" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let arguments = call.arguments as? [String: Any],
        let requestedPath = arguments["path"] as? String
      else {
        result(FlutterError(
          code: "invalid_location_store_path",
          message: "A location store path is required.",
          details: nil
        ))
        return
      }

      do {
        let supportDirectory = try FileManager.default.url(
          for: .applicationSupportDirectory,
          in: .userDomainMask,
          appropriateFor: nil,
          create: true
        )
        let locationDirectory = supportDirectory.appendingPathComponent(
          LocationStoreBackupExclusion.directoryName,
          isDirectory: true
        )
        let locationFile = locationDirectory.appendingPathComponent(
          LocationStoreBackupExclusion.fileName
        )
        guard URL(fileURLWithPath: requestedPath).standardizedFileURL ==
            locationFile.standardizedFileURL
        else {
          result(FlutterError(
            code: "invalid_location_store_path",
            message: "The location store path is outside application support.",
            details: nil
          ))
          return
        }
        try LocationStoreBackupExclusion.ensureExcluded(
          directoryURL: locationDirectory,
          fileURL: locationFile
        )
        result(nil)
      } catch {
        result(FlutterError(
          code: "location_backup_exclusion_failed",
          message: "The location store backup exclusion could not be verified.",
          details: nil
        ))
      }
    }
    FlutterEventChannel(
      name: "com.offlinesky.sky/orientation/events",
      binaryMessenger: messenger
    ).setStreamHandler(motionHandler)
  }
}

enum LocationStoreBackupExclusion {
  static let directoryName = "offline_sky"
  static let fileName = "observer_location.json"

  static func ensureExcluded(directoryURL: URL, fileURL: URL) throws {
    try FileManager.default.createDirectory(
      at: directoryURL,
      withIntermediateDirectories: true
    )
    try directoryURL.setResourceValue(true, forKey: .isExcludedFromBackupKey)
    guard try directoryURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
      .isExcludedFromBackup == true
    else {
      throw NSError(domain: "OfflineSky.LocationBackup", code: 1)
    }

    if FileManager.default.fileExists(atPath: fileURL.path) {
      try fileURL.setResourceValue(true, forKey: .isExcludedFromBackupKey)
      guard try fileURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
        .isExcludedFromBackup == true
      else {
        throw NSError(domain: "OfflineSky.LocationBackup", code: 2)
      }
    }
  }
}

private final class OfflineSkyMotionStreamHandler: NSObject,
  FlutterStreamHandler,
  CLLocationManagerDelegate {
  private let motionManager = CMMotionManager()
  private let locationManager = CLLocationManager()
  private var eventSink: FlutterEventSink?
  private var usesTrueNorth = false
  private var observerLocation: CLLocation?
  private var latestLocation: CLLocation?
  private var latestHeading: CLHeading?
  private var lastPublishedAvailability: Bool?

  override init() {
    super.init()
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    locationManager.distanceFilter = 100
  }

  func setObserverLocation(latitude: Double, longitude: Double) {
    performOnMain { handler in
      handler.observerLocation = CLLocation(latitude: latitude, longitude: longitude)
      handler.refreshDeclination()
      handler.updateLocationServices()
    }
  }

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    lastPublishedAvailability = nil
    guard motionManager.isDeviceMotionAvailable else {
      publishUnavailable()
      return nil
    }

    let frames = CMMotionManager.availableAttitudeReferenceFrames()
    usesTrueNorth = frames.contains(.xTrueNorthZVertical)
    let referenceFrame: CMAttitudeReferenceFrame = usesTrueNorth
      ? .xTrueNorthZVertical
      : .xMagneticNorthZVertical
    if !usesTrueNorth {
      updateLocationServices()
    }

    motionManager.deviceMotionUpdateInterval = 1.0 / 20.0
    motionManager.startDeviceMotionUpdates(using: referenceFrame, to: .main) { [weak self] motion, error in
      guard let self, let motion, error == nil else { return }
      self.publish(motion)
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    motionManager.stopDeviceMotionUpdates()
    locationManager.stopUpdatingHeading()
    locationManager.stopUpdatingLocation()
    latestLocation = nil
    latestHeading = nil
    eventSink = nil
    return nil
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    performOnMain { $0.updateLocationServices() }
  }

  func locationManager(
    _ manager: CLLocationManager,
    didUpdateLocations locations: [CLLocation]
  ) {
    let location = locations.last(where: { $0.horizontalAccuracy >= 0 })
    performOnMain { handler in
      handler.latestLocation = location
      handler.refreshDeclination()
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
    performOnMain { handler in
      handler.latestHeading = newHeading
      handler.refreshDeclination()
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    performOnMain { handler in
      handler.latestLocation = nil
      handler.latestHeading = nil
      handler.publishUnavailable()
    }
  }

  private func updateLocationServices() {
    guard eventSink != nil, !usesTrueNorth, observerLocation != nil else { return }
    let status = locationManager.authorizationStatus
    guard status == .authorizedWhenInUse || status == .authorizedAlways,
          CLLocationManager.headingAvailable() else {
      latestLocation = nil
      latestHeading = nil
      locationManager.stopUpdatingHeading()
      locationManager.stopUpdatingLocation()
      publishUnavailable()
      return
    }
    locationManager.startUpdatingLocation()
    locationManager.startUpdatingHeading()
  }

  private func refreshDeclination() {
    if case .unavailable = currentNorthCorrection(at: Date()) {
      publishUnavailable()
    }
  }

  private func currentNorthCorrection(at now: Date) -> OrientationNorthCorrection {
    northCorrectionForPublication(
      usesTrueNorth: usesTrueNorth,
      observerLocation: observerLocation?.coordinate,
      location: latestLocation.map {
        MagneticLocationSample(
          coordinate: $0.coordinate,
          horizontalAccuracyMeters: $0.horizontalAccuracy,
          timestamp: $0.timestamp
        )
      },
      heading: latestHeading.map {
        MagneticHeadingSample(
          magneticHeadingDegrees: $0.magneticHeading,
          trueHeadingDegrees: $0.trueHeading,
          accuracyDegrees: $0.headingAccuracy,
          timestamp: $0.timestamp
        )
      },
      authorizationStatus: locationManager.authorizationStatus,
      headingAvailable: CLLocationManager.headingAvailable(),
      now: now
    )
  }

  private func publish(_ motion: CMDeviceMotion) {
    let matrix = motion.attitude.rotationMatrix
    let camera = deviceToReference(matrix, x: 0, y: 0, z: -1)
    let (screenRight, screenUp) = screenAxes()
    let right = deviceToReference(matrix, x: screenRight.0, y: screenRight.1, z: 0)
    let up = deviceToReference(matrix, x: screenUp.0, y: screenUp.1, z: 0)
    var cameraEnu = coreMotionToEnu(camera)
    var rightEnu = coreMotionToEnu(right)
    var upEnu = coreMotionToEnu(up)

    switch currentNorthCorrection(at: Date()) {
    case .trueNorth:
      break
    case .unavailable:
      publishUnavailable()
      return
    case let .magnetic(declinationDegrees):
      cameraEnu = magneticEnuToTrue(
        cameraEnu,
        declinationDegrees: declinationDegrees
      )
      rightEnu = magneticEnuToTrue(
        rightEnu,
        declinationDegrees: declinationDegrees
      )
      upEnu = magneticEnuToTrue(
        upEnu,
        declinationDegrees: declinationDegrees
      )
    }

    let quality: String
    switch motion.magneticField.accuracy {
    case .high:
      quality = "high"
    case .medium:
      quality = "medium"
    case .low:
      quality = "low"
    default:
      quality = "low"
    }

    lastPublishedAvailability = true
    eventSink?([
      "available": true,
      "northReference": "true",
      "quality": quality,
      "cameraEast": cameraEnu.0,
      "cameraNorth": cameraEnu.1,
      "cameraUp": cameraEnu.2,
      "rightEast": rightEnu.0,
      "rightNorth": rightEnu.1,
      "rightUp": rightEnu.2,
      "upEast": upEnu.0,
      "upNorth": upEnu.1,
      "upUp": upEnu.2,
    ])
  }

  private func performOnMain(
    _ work: @escaping (OfflineSkyMotionStreamHandler) -> Void
  ) {
    guard !Thread.isMainThread else {
      work(self)
      return
    }
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      work(self)
    }
  }

  private func publishUnavailable() {
    guard lastPublishedAvailability != false else { return }
    lastPublishedAvailability = false
    eventSink?([
      "available": false,
      "northReference": "unavailable",
      "quality": "unavailable",
    ])
  }

  // Core Motion's true/magnetic frame uses X=north, Y=west, Z=up.
  private func coreMotionToEnu(
    _ vector: (Double, Double, Double)
  ) -> (Double, Double, Double) {
    (-vector.1, vector.0, vector.2)
  }

  private func deviceToReference(
    _ matrix: CMRotationMatrix,
    x: Double,
    y: Double,
    z: Double
  ) -> (Double, Double, Double) {
    (
      matrix.m11 * x + matrix.m12 * y + matrix.m13 * z,
      matrix.m21 * x + matrix.m22 * y + matrix.m23 * z,
      matrix.m31 * x + matrix.m32 * y + matrix.m33 * z
    )
  }

  private func screenAxes() -> ((Double, Double), (Double, Double)) {
    let orientation = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first?.interfaceOrientation
    switch orientation {
    case .some(.landscapeLeft):
      return ((0, 1), (-1, 0))
    case .some(.landscapeRight):
      return ((0, -1), (1, 0))
    case .some(.portraitUpsideDown):
      return ((-1, 0), (0, -1))
    default:
      return ((1, 0), (0, 1))
    }
  }
}

struct MagneticLocationSample {
  let coordinate: CLLocationCoordinate2D
  let horizontalAccuracyMeters: Double
  let timestamp: Date
}

struct MagneticHeadingSample {
  let magneticHeadingDegrees: Double
  let trueHeadingDegrees: Double
  let accuracyDegrees: Double
  let timestamp: Date
}

enum OrientationNorthCorrection: Equatable {
  case trueNorth
  case magnetic(declinationDegrees: Double)
  case unavailable
}

let magneticNorthSampleMaximumAge: TimeInterval = 120

func northCorrectionForPublication(
  usesTrueNorth: Bool,
  observerLocation: CLLocationCoordinate2D?,
  location: MagneticLocationSample?,
  heading: MagneticHeadingSample?,
  authorizationStatus: CLAuthorizationStatus,
  headingAvailable: Bool,
  now: Date
) -> OrientationNorthCorrection {
  guard !usesTrueNorth else { return .trueNorth }
  guard authorizationStatus == .authorizedWhenInUse ||
      authorizationStatus == .authorizedAlways,
    headingAvailable,
    let observerLocation,
    let location,
    let heading,
    observerLocation.latitude.isFinite,
    observerLocation.longitude.isFinite,
    CLLocationCoordinate2DIsValid(observerLocation),
    location.coordinate.latitude.isFinite,
    location.coordinate.longitude.isFinite,
    CLLocationCoordinate2DIsValid(location.coordinate),
    location.horizontalAccuracyMeters.isFinite,
    location.horizontalAccuracyMeters >= 0,
    heading.accuracyDegrees.isFinite,
    heading.accuracyDegrees >= 0,
    heading.accuracyDegrees <= 180,
    heading.trueHeadingDegrees.isFinite,
    heading.trueHeadingDegrees >= 0,
    heading.trueHeadingDegrees < 360,
    heading.magneticHeadingDegrees.isFinite,
    heading.magneticHeadingDegrees >= 0,
    heading.magneticHeadingDegrees < 360,
    isFresh(location.timestamp, at: now),
    isFresh(heading.timestamp, at: now)
  else {
    return .unavailable
  }

  let measuredLocation = CLLocation(
    latitude: location.coordinate.latitude,
    longitude: location.coordinate.longitude
  )
  let observer = CLLocation(
    latitude: observerLocation.latitude,
    longitude: observerLocation.longitude
  )
  let maximumDistance = max(1000, location.horizontalAccuracyMeters * 2)
  let distance = observer.distance(from: measuredLocation)
  guard maximumDistance.isFinite, distance.isFinite, distance <= maximumDistance else {
    return .unavailable
  }

  // Core Location's trueHeading uses geographic north; magneticHeading uses
  // magnetic north. Their signed difference is east-positive declination.
  return .magnetic(
    declinationDegrees: signedAngleDifference(
      heading.magneticHeadingDegrees,
      heading.trueHeadingDegrees
    )
  )
}

private func isFresh(_ timestamp: Date, at now: Date) -> Bool {
  let age = now.timeIntervalSince(timestamp)
  return age.isFinite && age >= 0 && age < magneticNorthSampleMaximumAge
}

func signedAngleDifference(_ fromDegrees: Double, _ toDegrees: Double) -> Double {
  var difference = (toDegrees - fromDegrees).truncatingRemainder(dividingBy: 360)
  if difference > 180 {
    difference -= 360
  } else if difference < -180 {
    difference += 360
  }
  return difference
}

func magneticEnuToTrue(
  _ vector: (Double, Double, Double),
  declinationDegrees: Double
) -> (Double, Double, Double) {
  let declination = declinationDegrees * .pi / 180
  let east = vector.0
  let north = vector.1
  return (
    east * cos(declination) + north * sin(declination),
    -east * sin(declination) + north * cos(declination),
    vector.2
  )
}
