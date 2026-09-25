//
//  SunCalculator.swift
//  sunset
//
//  Sun position and sunset timeline, calculated on the device.
//  Based on NOAA's solar calculator equations (accurate to about a minute).
//

import Foundation

struct SunPosition {
    /// Degrees above the horizon (negative = below).
    let altitude: Double
    /// Compass bearing in degrees from true north (0 = N, 90 = E, 180 = S, 270 = W).
    let azimuth: Double
}

struct SunsetTimeline {
    let sunrise: Date?
    let goldenHourStart: Date?
    let sunset: Date
    let blueHourStart: Date?
    let blueHourEnd: Date?
    /// Where the sun touches the horizon, degrees from true north.
    let sunsetAzimuth: Double
}

enum SunCalculator {
    // Sun altitudes that mark each phase.
    static let sunsetAltitude = -0.833   // upper edge of the sun at the horizon, with refraction
    static let goldenHourAltitude = 6.0
    static let blueHourStartAltitude = -4.0
    static let blueHourEndAltitude = -6.0 // civil dusk

    static func position(at date: Date, latitude: Double, longitude: Double) -> SunPosition {
        let julianDay = date.timeIntervalSince1970 / 86400 + 2440587.5
        let t = (julianDay - 2451545) / 36525 // Julian centuries since J2000

        let meanLongitude = (280.46646 + t * (36000.76983 + t * 0.0003032)).truncatingRemainder(dividingBy: 360)
        let meanAnomaly = 357.52911 + t * (35999.05029 - 0.0001537 * t)
        let eccentricity = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)

        let m = meanAnomaly.radians
        let center = sin(m) * (1.914602 - t * (0.004817 + 0.000014 * t))
            + sin(2 * m) * (0.019993 - 0.000101 * t)
            + sin(3 * m) * 0.000289
        let omega = (125.04 - 1934.136 * t).radians
        let apparentLongitude = meanLongitude + center - 0.00569 - 0.00478 * sin(omega)

        let meanObliquity = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60
        let obliquity = (meanObliquity + 0.00256 * cos(omega)).radians
        let declination = asin(sin(obliquity) * sin(apparentLongitude.radians))

        // Equation of time, in minutes.
        let y = pow(tan(obliquity / 2), 2)
        let l = meanLongitude.radians
        let equationOfTime = 4 * (y * sin(2 * l)
            - 2 * eccentricity * sin(m)
            + 4 * eccentricity * y * sin(m) * cos(2 * l)
            - 0.5 * y * y * sin(4 * l)
            - 1.25 * eccentricity * eccentricity * sin(2 * m)).degrees

        let utcMinutes = date.timeIntervalSince1970.truncatingRemainder(dividingBy: 86400) / 60
        var trueSolarTime = (utcMinutes + equationOfTime + 4 * longitude).truncatingRemainder(dividingBy: 1440)
        if trueSolarTime < 0 { trueSolarTime += 1440 }
        let hourAngle = trueSolarTime / 4 < 0 ? trueSolarTime / 4 + 180 : trueSolarTime / 4 - 180

        let lat = latitude.radians
        let cosZenith = sin(lat) * sin(declination) + cos(lat) * cos(declination) * cos(hourAngle.radians)
        let zenith = acos(min(max(cosZenith, -1), 1))

        let azimuthCos = (sin(lat) * cos(zenith) - sin(declination)) / (cos(lat) * sin(zenith))
        let azimuthAngle = acos(min(max(azimuthCos, -1), 1)).degrees
        let azimuth = hourAngle > 0
            ? (azimuthAngle + 180).truncatingRemainder(dividingBy: 360)
            : (540 - azimuthAngle).truncatingRemainder(dividingBy: 360)

        return SunPosition(altitude: 90 - zenith.degrees, azimuth: azimuth)
    }

    /// The sunset timeline for the calendar day containing `date`, in `timeZone`.
    /// Returns nil when the sun doesn't set that day (polar summer or winter).
    static func timeline(on date: Date, latitude: Double, longitude: Double,
                         timeZone: TimeZone = .current) -> SunsetTimeline? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return nil }

        func altitude(_ d: Date) -> Double {
            position(at: d, latitude: latitude, longitude: longitude).altitude
        }

        // Solar noon: the highest point of the day, found on a 5-minute grid.
        let step: TimeInterval = 300
        var noon = dayStart
        var t = dayStart
        while t < dayEnd {
            if altitude(t) > altitude(noon) { noon = t }
            t += step
        }

        guard let sunset = crossing(of: sunsetAltitude, from: noon, to: dayEnd, rising: false, altitude: altitude) else {
            return nil
        }
        let nextDayEnd = dayEnd + 6 * 3600 // blue hour can run past midnight in summer up north

        return SunsetTimeline(
            sunrise: crossing(of: sunsetAltitude, from: dayStart, to: noon, rising: true, altitude: altitude),
            goldenHourStart: crossing(of: goldenHourAltitude, from: noon, to: sunset, rising: false, altitude: altitude),
            sunset: sunset,
            blueHourStart: crossing(of: blueHourStartAltitude, from: sunset, to: nextDayEnd, rising: false, altitude: altitude),
            blueHourEnd: crossing(of: blueHourEndAltitude, from: sunset, to: nextDayEnd, rising: false, altitude: altitude),
            sunsetAzimuth: position(at: sunset, latitude: latitude, longitude: longitude).azimuth
        )
    }

    /// First time between `start` and `end` when the sun passes `target` altitude,
    /// scanning in 5-minute steps and then narrowing down to the second.
    private static func crossing(of target: Double, from start: Date, to end: Date, rising: Bool,
                                 altitude: (Date) -> Double) -> Date? {
        let step: TimeInterval = 300
        var previous = start
        var t = start + step
        while t <= end {
            let before = altitude(previous) - target
            let after = altitude(t) - target
            let crossed = rising ? (before < 0 && after >= 0) : (before > 0 && after <= 0)
            if crossed {
                var low = previous, high = t
                while high.timeIntervalSince(low) > 1 {
                    let mid = low + high.timeIntervalSince(low) / 2
                    let aboveTarget = altitude(mid) - target > 0
                    if aboveTarget == rising { high = mid } else { low = mid }
                }
                return low
            }
            previous = t
            t += step
        }
        return nil
    }

    /// "W", "WSW", etc. for a bearing in degrees.
    static func compassPoint(for bearing: Double) -> String {
        let points = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                      "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((bearing / 22.5).rounded()) % 16
        return points[(index + 16) % 16]
    }
}

private extension Double {
    var radians: Double { self * .pi / 180 }
    var degrees: Double { self * 180 / .pi }
}
