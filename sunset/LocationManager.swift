//
//  LocationManager.swift
//  sunset
//
//  Wraps Core Location: asks for permission only when the user picks "current location",
//  gets a location fix, and streams the compass heading (which works for any chosen place).
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
    /// A readable place name for the coordinate, e.g. "Chicago, IL". Nil until looked up.
    private(set) var placeName: String?
    /// Which way the top of the phone points, degrees from true north. Nil when there's no compass (e.g. the Simulator).
    private(set) var heading: Double?

    var isDenied: Bool {
        [.denied, .restricted].contains(manager.authorizationStatus)
    }

    private let manager = CLLocationManager()
    /// True once the user has chosen "current location"; until then, no location is used.
    private var wantsLocation = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer // city-level is plenty for sunset times
    }

    /// Call when the user picks "current location" (or on launch if they already have).
    /// Shows the permission prompt the first time.
    func requestLocation() {
        wantsLocation = true
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            status = coordinate == nil ? .locating : status
            manager.requestLocation()
        default:
            status = .denied
        }
    }

    /// Stop following the phone's location (the user picked a place by hand).
    func stopUsingLocation() {
        wantsLocation = false
    }

    /// The compass. Works without location permission (it falls back to magnetic north).
    func startHeading() {
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    // MARK: CLLocationManagerDelegate
    // Core Location calls these on the main thread, since the manager was created there.

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let authorization = manager.authorizationStatus
        MainActor.assumeIsolated {
            switch authorization {
            case .authorizedWhenInUse, .authorizedAlways:
                if wantsLocation { requestLocation() }
            case .denied, .restricted:
                status = .denied
            default:
                status = .notAsked
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last?.coordinate else { return }
        MainActor.assumeIsolated {
            coordinate = latest
            status = .located
            Task { await lookUpPlaceName(for: latest) }
        }
    }

    private func lookUpPlaceName(for coordinate: CLLocationCoordinate2D) async {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let place = try? await CLGeocoder().reverseGeocodeLocation(location).first else { return }
        placeName = PlaceSearch.name(for: place)
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
