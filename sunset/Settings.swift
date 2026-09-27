//
//  Settings.swift
//  sunset
//
//  What the app remembers between launches: the chosen location and notification preferences.
//

import Foundation
import Observation

/// A place picked by hand (zip code or town search).
struct Place: Codable, Equatable {
    var name: String
    var latitude: Double
    var longitude: Double
    /// "Somewhere around here", in km. Nil means the exact spot.
    /// Sunset times barely change across a few km, so the forecast uses the center.
    var radiusKm: Double?

    var displayName: String {
        guard let radiusKm else { return name }
        return "Near \(name) (\(Int(radiusKm)) km)"
    }
}

enum LocationChoice: Codable, Equatable {
    /// First launch, before the user picks: a sample city with real data.
    case sample
    /// Follow the phone's location.
    case current
    case manual(Place)
}

@Observable
final class Settings {
    /// Shown on first launch. Change freely.
    static let sampleCity = Place(name: "San Francisco, CA", latitude: 37.7749, longitude: -122.4194)

    /// How long before sunset the notification arrives.
    static let notifyMinutesBefore = 45

    var locationChoice: LocationChoice {
        didSet { save(locationChoice, for: Keys.locationChoice) }
    }

    /// The user's own switch. iOS permission is separate (see NotificationScheduler).
    var notificationsOn: Bool {
        didSet { defaults.set(notificationsOn, forKey: Keys.notificationsOn) }
    }

    /// True once the user has answered the "turn on notifications" card, either way.
    var notificationCardAnswered: Bool {
        didSet { defaults.set(notificationCardAnswered, forKey: Keys.notificationCardAnswered) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        locationChoice = Self.load(LocationChoice.self, from: defaults, key: Keys.locationChoice) ?? .sample
        notificationsOn = defaults.bool(forKey: Keys.notificationsOn)
        notificationCardAnswered = defaults.bool(forKey: Keys.notificationCardAnswered)
    }

    /// Start over as if on first launch (for testing).
    func reset() {
        locationChoice = .sample
        notificationsOn = false
        notificationCardAnswered = false
    }

    private enum Keys {
        static let locationChoice = "locationChoice"
        static let notificationsOn = "notificationsOn"
        static let notificationCardAnswered = "notificationCardAnswered"
    }

    private func save<T: Encodable>(_ value: T, for key: String) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }

    private static func load<T: Decodable>(_ type: T.Type, from defaults: UserDefaults, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
