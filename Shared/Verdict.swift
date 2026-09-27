//
//  Verdict.swift
//  sunset
//
//  Turns sky conditions into a gentle verdict and a "step out at ___ for ___" window.
//  The rules are simple starting points, meant to be tuned against real sunsets.
//

import Foundation

enum NightType: String, CaseIterable {
    /// Some mid or high cloud to catch the color, and nothing blocking the light.
    case pretty
    /// Some chance of color, but something's off (a lot of cloud, some rain risk).
    case maybe
    /// Almost no cloud: a clean, soft glow without much color.
    case clear
    /// Heavy low or mid cloud.
    case quiet
    /// Likely rain.
    case rain
}

struct Verdict {
    /// Nil when there's no forecast to judge by.
    let night: NightType?
    let headline: String
    /// "Step out around 7:02 for about 25 minutes." Nil on quiet or rainy nights.
    let stepOutLine: String?
    let stepOut: Date?
    let stayUntil: Date?
    /// True when this is about tomorrow because tonight's sunset is over.
    let isTomorrow: Bool

    static func make(timeline: SunsetTimeline, conditions: SkyConditions?, isTomorrow: Bool,
                     timeZone: TimeZone = .current) -> Verdict {
        let sunsetTime = format(timeline.sunset, in: timeZone)

        guard let conditions else {
            return Verdict(night: nil,
                           headline: VerdictCopy.noForecast(sunsetTime: sunsetTime, tomorrow: isTomorrow),
                           stepOutLine: nil, stepOut: nil, stayUntil: nil, isTomorrow: isTomorrow)
        }

        let night = classify(conditions)
        let window = viewingWindow(for: night, timeline: timeline)
        let lines = VerdictCopy.lines(for: night, tomorrow: isTomorrow)
        // Same line all day, a different one on different days.
        let day = Calendar.current.ordinality(of: .day, in: .era, for: timeline.sunset) ?? 0
        let headline = lines[day % lines.count]

        var stepOutLine: String?
        if let window {
            let minutes = Int((window.end.timeIntervalSince(window.start) / 60 / 5).rounded()) * 5
            stepOutLine = VerdictCopy.stepOut(at: format(window.start, in: timeZone), forMinutes: minutes)
        }

        return Verdict(night: night, headline: headline, stepOutLine: stepOutLine,
                       stepOut: window?.start, stayUntil: window?.end, isTomorrow: isTomorrow)
    }

    /// The rules. High and mid clouds catch color; low clouds block it.
    static func classify(_ c: SkyConditions) -> NightType {
        if c.rainChance >= 60 { return .rain }
        // Thick low or mid cloud blocks the light. A full sheet of thin high cloud alone doesn't, so it isn't counted here.
        if c.lowCloud >= 70 || c.midCloud >= 90 { return .quiet }

        let colorClouds = max(c.midCloud, c.highCloud)
        let horizonBlocked = (c.horizonLowCloud ?? 0) >= 60
        if (20...80).contains(colorClouds) && c.lowCloud < 50 && !horizonBlocked {
            return c.rainChance >= 30 ? .maybe : .pretty
        }
        if c.totalCloud < 15 { return .clear }
        return .maybe
    }

    /// When to be outside. The best color often comes after the sun is down, so good nights run into blue hour.
    static func viewingWindow(for night: NightType, timeline: SunsetTimeline) -> DateInterval? {
        let sunset = timeline.sunset
        let minute: TimeInterval = 60
        switch night {
        case .pretty:
            let end = timeline.blueHourStart ?? sunset + 25 * minute
            return DateInterval(start: sunset - 10 * minute, end: max(end, sunset + 15 * minute))
        case .maybe:
            return DateInterval(start: sunset - 10 * minute, end: sunset + 15 * minute)
        case .clear:
            return DateInterval(start: sunset - 15 * minute, end: sunset + 10 * minute)
        case .quiet, .rain:
            return nil
        }
    }

    private static func format(_ date: Date, in timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}
