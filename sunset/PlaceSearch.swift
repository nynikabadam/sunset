//
//  PlaceSearch.swift
//  sunset
//
//  Turns a zip code or town name into places to pick from.
//

import CoreLocation

enum PlaceSearch {
    static func search(_ text: String) async -> [Place] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty,
              let placemarks = try? await CLGeocoder().geocodeAddressString(query) else { return [] }

        return placemarks.compactMap { placemark in
            guard let coordinate = placemark.location?.coordinate else { return nil }
            return Place(name: name(for: placemark), latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
    }

    /// "Chicago, IL" in the US; "London, United Kingdom" elsewhere.
    static func name(for placemark: CLPlacemark) -> String {
        let city = placemark.locality ?? placemark.subAdministrativeArea ?? placemark.name
        let region = placemark.isoCountryCode == "US" ? placemark.administrativeArea : placemark.country
        return [city, region].compactMap { $0 }.joined(separator: ", ")
    }
}
