//
//  WeatherService.swift
//  sunset
//
//  Fetches the hourly sky forecast from Open-Meteo (free, no API key).
//  Two points in one request: where you are, and a point toward the sunset,
//  to check whether low cloud on the horizon will block the light.
//

import Foundation

/// Sky conditions for one hour.
struct SkyConditions: Equatable {
    /// Cloud cover percentages, 0–100.
    let lowCloud: Int
    let midCloud: Int
    let highCloud: Int
    let totalCloud: Int
    /// Chance of rain, 0–100.
    let rainChance: Int
    let visibilityKm: Double
    /// Low cloud toward the sunset, 0–100. Nil if that point couldn't be read.
    let horizonLowCloud: Int?
}

/// The hourly forecast for a location, a few days ahead.
struct SkyForecast {
    let timeZone: TimeZone
    fileprivate let local: OpenMeteoResponse.Hourly
    fileprivate let horizon: OpenMeteoResponse.Hourly?

    /// Conditions for the forecast hour closest to `date`. Nil if `date` is outside the forecast.
    func conditions(at date: Date) -> SkyConditions? {
        let target = date.timeIntervalSince1970
        guard let index = local.time.indices.min(by: { abs(Double(local.time[$0]) - target) < abs(Double(local.time[$1]) - target) }),
              abs(Double(local.time[index]) - target) <= 3600 else { return nil }

        let horizonLow = horizon.flatMap { h in
            h.time.firstIndex(of: local.time[index]).flatMap { h.cloud_cover_low[$0] }
        }

        return SkyConditions(
            lowCloud: local.cloud_cover_low[index] ?? 0,
            midCloud: local.cloud_cover_mid[index] ?? 0,
            highCloud: local.cloud_cover_high[index] ?? 0,
            totalCloud: local.cloud_cover[index] ?? 0,
            rainChance: local.precipitation_probability[index] ?? 0,
            visibilityKm: (local.visibility[index] ?? 0) / 1000,
            horizonLowCloud: horizonLow
        )
    }
}

enum WeatherService {
    /// How far toward the sunset to check for low cloud. A rough rule of thumb.
    static let horizonCheckDistanceKm = 100.0

    static func forecast(latitude: Double, longitude: Double, sunsetAzimuth: Double) async throws -> SkyForecast {
        let horizon = point(fromLatitude: latitude, longitude: longitude,
                            bearing: sunsetAzimuth, distanceKm: horizonCheckDistanceKm)

        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f,%.4f", latitude, horizon.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f,%.4f", longitude, horizon.longitude)),
            URLQueryItem(name: "hourly", value: "cloud_cover,cloud_cover_low,cloud_cover_mid,cloud_cover_high,precipitation_probability,visibility"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "forecast_days", value: "3"),
        ]

        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        // Several coordinates come back as an array, in the order requested.
        let points = try JSONDecoder().decode([OpenMeteoResponse].self, from: data)
        guard let here = points.first else { throw URLError(.cannotParseResponse) }

        return SkyForecast(
            timeZone: TimeZone(identifier: here.timezone) ?? .current,
            local: here.hourly,
            horizon: points.dropFirst().first?.hourly
        )
    }

    /// The point `distanceKm` away from a coordinate along a compass bearing.
    static func point(fromLatitude latitude: Double, longitude: Double,
                      bearing: Double, distanceKm: Double) -> (latitude: Double, longitude: Double) {
        let angular = distanceKm / 6371
        let lat1 = latitude * .pi / 180, lon1 = longitude * .pi / 180, theta = bearing * .pi / 180
        let lat2 = asin(sin(lat1) * cos(angular) + cos(lat1) * sin(angular) * cos(theta))
        let lon2 = lon1 + atan2(sin(theta) * sin(angular) * cos(lat1), cos(angular) - sin(lat1) * sin(lat2))
        return (lat2 * 180 / .pi, (lon2 * 180 / .pi + 540).truncatingRemainder(dividingBy: 360) - 180)
    }
}

/// The parts of Open-Meteo's JSON we use.
private struct OpenMeteoResponse: Decodable {
    let timezone: String
    let hourly: Hourly

    struct Hourly: Decodable {
        let time: [Int]
        let cloud_cover: [Int?]
        let cloud_cover_low: [Int?]
        let cloud_cover_mid: [Int?]
        let cloud_cover_high: [Int?]
        let precipitation_probability: [Int?]
        let visibility: [Double?]
    }
}
