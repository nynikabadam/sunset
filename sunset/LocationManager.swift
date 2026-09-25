//
//  LocationManager.swift
//  sunset
//
//  Wraps Core Location: asks for permission when the user taps,
//  gets one location fix, and streams the compass heading.
//

import CoreLocation
import Observation

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    enum Status {
        case notAsked, denied, locating, located
    }

    private(set) var status: Status = .notAsked
    private(set) var coordinate: CLLocationCoordinate2D?
    /// Which way the top of the phone points, degrees from true north. Nil when there's no compass (e.g. the Simulator).
    private(set) var heading: Double?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer // city-level is plenty for sunset times
        updateStatus(manager.authorizationStatus)
    }

    /// Call from a button tap, so the permission prompt appears when the value is obvious.
    func requestLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            start()
        default:
            status = .denied
        }
    }

    private func start() {
        status = .locating
        manager.requestLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    private func updateStatus(_ authorization: CLAuthorizationStatus) {
        switch authorization {
        case .authorizedWhenInUse, .authorizedAlways:
            if coordinate == nil { start() }
        case .denied, .restricted:
            status = .denied
        default:
            status = .notAsked
        }
    }

    // MARK: CLLocationManagerDelegate
    // Core Location calls these on the main thread, since the manager was created there.

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let authorization = manager.authorizationStatus
        MainActor.assumeIsolated { updateStatus(authorization) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last?.coordinate else { return }
        MainActor.assumeIsolated {
            coordinate = latest
            status = .located
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // trueHeading is negative until the phone has a location fix; fall back to magnetic until then.
        let degrees = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        MainActor.assumeIsolated { heading = degrees }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            if coordinate == nil { status = .notAsked }
        }
    }
}
