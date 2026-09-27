//
//  NotificationScheduler.swift
//  sunset
//
//  The evening notification: asks permission, and schedules one notification
//  before each sunset for the next week. Rescheduled every time the app loads a forecast,
//  so times stay right as the seasons shift or the location changes.
//
//  Pressing and holding the notification opens the SunsetNotification extension,
//  which loads that evening's conditions live.
//

import Foundation
import UserNotifications

enum NotificationScheduler {
    /// Links notifications to the press-and-hold view. Must match the extension's Info.plist.
    static let category = "SUNSET_PREVIEW"
    static let daysAhead = 7
    private static let idPrefix = "sunset-"

    private static var center: UNUserNotificationCenter { .current() }

    static func registerCategory() {
        let category = UNNotificationCategory(identifier: category, actions: [], intentIdentifiers: [])
        center.setNotificationCategories([category])
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Shows the iOS permission prompt (only the first time). Returns whether notifications are allowed.
    static func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Replaces any scheduled sunset notifications with fresh ones for the coming week.
    static func reschedule(latitude: Double, longitude: Double, placeName: String?, timeZone: TimeZone,
                           minutesBefore: Int, now: Date = .now) async {
        await cancelAll()

        for day in 0..<daysAhead {
            guard let timeline = SunCalculator.timeline(on: now + Double(day) * 86400,
                                                        latitude: latitude, longitude: longitude,
                                                        timeZone: timeZone) else { continue }
            let fireDate = timeline.sunset - Double(minutesBefore) * 60
            guard fireDate > now else { continue }

            let content = makeContent(timeline: timeline, latitude: latitude, longitude: longitude,
                                      placeName: placeName, timeZone: timeZone, minutesBefore: minutesBefore)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fireDate.timeIntervalSince(now), repeats: false)
            let id = idPrefix + ISO8601DateFormatter().string(from: timeline.sunset)
            try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }

    static func cancelAll() async {
        let ids = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// A notification in a few seconds, for trying out the press-and-hold view without waiting for sunset.
    static func sendTest(latitude: Double, longitude: Double, placeName: String?, timeZone: TimeZone) async {
        guard let timeline = SunCalculator.timeline(on: .now, latitude: latitude, longitude: longitude,
                                                    timeZone: timeZone) else { return }
        let content = makeContent(timeline: timeline, latitude: latitude, longitude: longitude,
                                  placeName: placeName, timeZone: timeZone,
                                  minutesBefore: Settings.notifyMinutesBefore)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: "test-\(UUID())", content: content, trigger: trigger))
    }

    /// The collapsed notification: time and direction only. Conditions load on press and hold.
    private static func makeContent(timeline: SunsetTimeline, latitude: Double, longitude: Double,
                                    placeName: String?, timeZone: TimeZone, minutesBefore: Int) -> UNMutableNotificationContent {
        let time = timeline.sunset.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: timeZone))
        let direction = SunCalculator.compassPoint(for: timeline.sunsetAzimuth)

        let content = UNMutableNotificationContent()
        content.title = "Sunset in \(minutesBefore) minutes"
        content.body = "\(time), facing \(direction). Press and hold to see tonight's sky."
        content.sound = .default
        content.categoryIdentifier = category
        // The press-and-hold view reads these to load the live forecast.
        content.userInfo = ["latitude": latitude, "longitude": longitude, "placeName": placeName ?? ""]
        return content
    }
}
