//
//  ForecastModel.swift
//  sunset
//
//  Puts it together: sunset timeline + sky forecast → verdict.
//  Once tonight's viewing window is over, it switches to tomorrow.
//

import Foundation
import Observation

struct SunsetReport {
    let timeline: SunsetTimeline
    let conditions: SkyConditions?
    let verdict: Verdict
    let timeZone: TimeZone
}

@Observable
final class ForecastModel {
    enum State {
        case idle
        case loading
        case loaded(SunsetReport, forecastFailed: Bool)
        /// Polar day or night: no sunset today or tomorrow.
        case noSunset
    }

    private(set) var state: State = .idle

    func load(latitude: Double, longitude: Double, now: Date = .now) async {
        if case .idle = state { state = .loading }

        // A first pass in the phone's time zone gives the sunset direction for the horizon check.
        let firstGuess = SunCalculator.timeline(on: now, latitude: latitude, longitude: longitude)
        let forecast = try? await WeatherService.forecast(latitude: latitude, longitude: longitude,
                                                          sunsetAzimuth: firstGuess?.sunsetAzimuth ?? 270)
        // Use the location's own time zone when we have it (matters for places chosen by hand).
        let timeZone = forecast?.timeZone ?? .current

        func report(for day: Date, isTomorrow: Bool) -> SunsetReport? {
            guard let timeline = SunCalculator.timeline(on: day, latitude: latitude, longitude: longitude,
                                                        timeZone: timeZone) else { return nil }
            let conditions = forecast?.conditions(at: timeline.sunset)
            let verdict = Verdict.make(timeline: timeline, conditions: conditions,
                                       isTomorrow: isTomorrow, timeZone: timeZone)
            return SunsetReport(timeline: timeline, conditions: conditions, verdict: verdict, timeZone: timeZone)
        }

        var chosen = report(for: now, isTomorrow: false)
        let tonightIsOver = chosen.map { now > Self.afterSunsetCutoff($0) } ?? true
        if tonightIsOver {
            chosen = report(for: now + 86400, isTomorrow: true)
        }

        if let chosen {
            state = .loaded(chosen, forecastFailed: forecast == nil)
        } else {
            state = .noSunset
        }
    }

    /// When the app stops talking about tonight: the end of the viewing window,
    /// or 15 minutes after sunset on nights without one.
    static func afterSunsetCutoff(_ report: SunsetReport) -> Date {
        report.verdict.stayUntil ?? report.timeline.sunset + 15 * 60
    }
}
