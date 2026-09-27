//
//  VerdictCopy.swift
//  sunset
//
//  The one-line verdicts. DRAFTS by Claude — rewrite these in your own voice.
//  Add or remove lines freely; the app picks one per day and keeps it all day.
//  Keep the tone no-pressure: it's a suggestion, never a demand.
//

enum VerdictCopy {
    static func lines(for night: NightType, tomorrow: Bool) -> [String] {
        switch (night, tomorrow) {
        case (.pretty, false):
            return ["Tonight could be a pretty one.",
                    "The sky's setting up for something nice.",
                    "Good clouds tonight. Worth a look if you're free."]
        case (.pretty, true):
            return ["Tomorrow could be a pretty one.",
                    "Tomorrow's sky looks promising."]

        case (.maybe, false):
            return ["Could go either way tonight.",
                    "Maybe a little color tonight."]
        case (.maybe, true):
            return ["Tomorrow might bring a little color."]

        case (.clear, false):
            return ["Clear skies tonight. A soft, simple glow.",
                    "Not much drama tonight, just a clean fade."]
        case (.clear, true):
            return ["Clear skies tomorrow. A soft, simple glow."]

        case (.quiet, false):
            return ["Probably a quiet one tonight.",
                    "Grey skies tonight. The sun will be back."]
        case (.quiet, true):
            return ["Tomorrow looks like a quiet one."]

        case (.rain, false):
            return ["Rain's in the way tonight. Stay cozy.",
                    "Probably too wet to see much tonight."]
        case (.rain, true):
            return ["Rain likely tomorrow evening."]
        }
    }

    /// The second line on nights worth stepping out, e.g. "Step out around 7:02 for about 25 minutes."
    static func stepOut(at time: String, forMinutes minutes: Int) -> String {
        "Step out around \(time) for about \(minutes) minutes."
    }

    /// The offline screen. Sunset times still work offline, since they're calculated on the phone.
    static func offline(sunsetTime: String) -> String {
        "No signal, no forecast. The sun's still setting at \(sunsetTime), though."
    }

    /// Shown when there's no forecast (offline or the fetch failed).
    static func noForecast(sunsetTime: String, tomorrow: Bool) -> String {
        tomorrow ? "Tomorrow's sunset is at \(sunsetTime)." : "Sunset's at \(sunsetTime) tonight."
    }
}
