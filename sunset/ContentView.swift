//
//  ContentView.swift
//  sunset
//
//  Test screen: tonight's verdict, sunset time, direction and sky conditions,
//  plus the location, notification and offline states.
//  Placeholder layout; the real design comes from Figma.
//

import SwiftUI
import CoreLocation
import UserNotifications

struct ContentView: View {
    @State private var location = LocationManager()
    @State private var forecast = ForecastModel()
    @State private var settings = Settings()
    @State private var network = NetworkMonitor()
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showingLocationSheet = false
    @State private var showingSettings = false
    @Environment(\.scenePhase) private var scenePhase

    /// The place the forecast is for, whichever way it was chosen.
    private struct ActivePlace {
        let latitude: Double
        let longitude: Double
        let name: String?
        let isSample: Bool
    }

    private var activePlace: ActivePlace? {
        switch settings.locationChoice {
        case .sample:
            let city = Settings.sampleCity
            return ActivePlace(latitude: city.latitude, longitude: city.longitude, name: city.name, isSample: true)
        case .current:
            guard let c = location.coordinate else { return nil }
            return ActivePlace(latitude: c.latitude, longitude: c.longitude, name: location.placeName, isSample: false)
        case .manual(let place):
            return ActivePlace(latitude: place.latitude, longitude: place.longitude, name: place.displayName, isSample: false)
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(colors: [Color(red: 0.12, green: 0.14, blue: 0.32),
                                    Color(red: 0.85, green: 0.42, blue: 0.30),
                                    Color(red: 0.98, green: 0.76, blue: 0.45)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            content

            Button { showingSettings = true } label: {
                Image(systemName: "gearshape.fill").font(.title3).padding(20)
            }
            .foregroundStyle(.white)
            .accessibilityLabel("Settings")
        }
        .sheet(isPresented: $showingLocationSheet) {
            NavigationStack { LocationPicker(settings: settings, location: location) }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsSheet(settings: settings, location: location, notificationStatus: notificationStatus,
                          placeName: activePlace?.name, onSendTest: sendTestNotification)
        }
        .onAppear {
            location.startHeading()
            if settings.locationChoice == .current { location.requestLocation() }
        }
        // A new place starts fresh (so the old place's forecast doesn't linger), then loads.
        .task(id: placeKey) {
            forecast = ForecastModel()
            await refresh()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await refresh() } }
        }
        .onChange(of: network.isOnline) { _, online in
            if online { Task { await refresh() } }
        }
        .onChange(of: settings.notificationsOn) { _, _ in
            Task { await refresh() }
        }
    }

    // MARK: Screens

    @ViewBuilder
    private var content: some View {
        if activePlace == nil {
            // Chose current location, but there's no fix yet.
            if location.isDenied {
                message("Location is off",
                        detail: "Turn it on in Settings → Privacy → Location Services, or pick a place by hand.",
                        button: "Pick a place") { showingLocationSheet = true }
            } else {
                ProgressView("Finding you…").tint(.white).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            switch forecast.state {
            case .idle, .loading:
                ProgressView("Checking the sky…").tint(.white).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .noSunset:
                message("No sunset here", detail: "The sun doesn't set here today or tomorrow.",
                        button: "Change location") { showingLocationSheet = true }
            case .loaded(let report, let forecastFailed):
                ScrollView {
                    VStack(spacing: 20) {
                        header(report)
                        if showNotificationCard { notificationCard }
                        SunsetDetails(report: report, heading: location.heading,
                                      forecastFailed: forecastFailed, isOffline: !network.isOnline)
                    }
                    .padding(.top, 8)
                }
                .refreshable { await refresh() }
            }
        }
    }

    /// "Sat, Sep 27 · Chicago, IL" — tap to change location.
    private func header(_ report: SunsetReport) -> some View {
        let date = report.timeline.sunset.formatted(
            Date.FormatStyle(timeZone: report.timeZone).weekday(.abbreviated).month(.abbreviated).day())
        let isSample = activePlace?.isSample ?? false

        return Button { showingLocationSheet = true } label: {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text([date, activePlace?.name ?? "Finding city…"].joined(separator: " · "))
                    Image(systemName: "chevron.down").font(.caption2)
                }
                .font(.subheadline.weight(.medium))
                if isSample {
                    Text("Sample city · tap to use yours")
                        .font(.caption)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(.white.opacity(0.2), in: .capsule)
                }
            }
        }
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 60) // clear of the settings button
    }

    private var showNotificationCard: Bool {
        !(activePlace?.isSample ?? true) && !settings.notificationCardAnswered && notificationStatus == .notDetermined
    }

    private var notificationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Want a heads-up?").font(.headline)
            Text("A notification \(Settings.notifyMinutesBefore) minutes before sunset, every evening. Press and hold it to see the sky.")
                .font(.callout)
            HStack {
                Button("Turn on") {
                    Task {
                        settings.notificationsOn = await NotificationScheduler.requestPermission()
                        settings.notificationCardAnswered = true
                        notificationStatus = await NotificationScheduler.authorizationStatus()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.3))
                Button("Not now") { settings.notificationCardAnswered = true }
                    .opacity(0.8)
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.2), in: .rect(cornerRadius: 16))
        .padding(.horizontal, 24)
    }

    private func message(_ title: String, detail: String, button: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 12) {
            Text(title).font(.title2.bold())
            Text(detail).multilineTextAlignment(.center).opacity(0.85)
            Button(button, action: action)
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.25))
        }
        .foregroundStyle(.white)
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Loading and notifications

    private var placeKey: String {
        guard let p = activePlace else { return "none" }
        return String(format: "%.3f,%.3f", p.latitude, p.longitude)
    }

    private func refresh() async {
        notificationStatus = await NotificationScheduler.authorizationStatus()
        guard let place = activePlace else { return }
        await forecast.load(latitude: place.latitude, longitude: place.longitude)

        // Keep the week of notifications in step with the place and the season.
        let authorized = [.authorized, .provisional].contains(notificationStatus)
        if settings.notificationsOn && authorized && !place.isSample, case .loaded(let report, _) = forecast.state {
            await NotificationScheduler.reschedule(latitude: place.latitude, longitude: place.longitude,
                                                   placeName: place.name, timeZone: report.timeZone,
                                                   minutesBefore: Settings.notifyMinutesBefore)
        } else {
            await NotificationScheduler.cancelAll()
        }
    }

    private func sendTestNotification() {
        guard let place = activePlace else { return }
        let timeZone: TimeZone
        if case .loaded(let report, _) = forecast.state { timeZone = report.timeZone } else { timeZone = .current }
        Task {
            if notificationStatus == .notDetermined {
                _ = await NotificationScheduler.requestPermission()
                notificationStatus = await NotificationScheduler.authorizationStatus()
            }
            await NotificationScheduler.sendTest(latitude: place.latitude, longitude: place.longitude,
                                                 placeName: place.name, timeZone: timeZone)
        }
    }
}

// MARK: - Main screen content

private struct SunsetDetails: View {
    let report: SunsetReport
    let heading: Double?
    let forecastFailed: Bool
    let isOffline: Bool

    private var timeline: SunsetTimeline { report.timeline }

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                if forecastFailed && isOffline {
                    Text(VerdictCopy.offline(sunsetTime: timeString(timeline.sunset)))
                        .font(.title2.bold())
                } else {
                    Text(report.verdict.headline)
                        .font(.title2.bold())
                    if let stepOut = report.verdict.stepOutLine {
                        Text(stepOut).opacity(0.9)
                    }
                    if forecastFailed {
                        Text("Couldn't load the forecast. Pull down to try again.")
                            .font(.caption)
                            .opacity(0.7)
                    }
                }
            }
            .multilineTextAlignment(.center)

            VStack(spacing: 4) {
                Text(report.verdict.isTomorrow ? "Tomorrow's sunset" : "Sunset")
                    .font(.headline)
                    .opacity(0.8)
                Text(timeString(timeline.sunset))
                    .font(.system(size: 64, weight: .semibold, design: .rounded))
            }

            SunCompass(sunsetAzimuth: timeline.sunsetAzimuth, heading: heading)

            card {
                row("Golden hour starts", timeline.goldenHourStart)
                row("Sunset", timeline.sunset)
                row("Blue hour starts", timeline.blueHourStart)
                row("Blue hour ends", timeline.blueHourEnd)
                Divider().overlay(.white.opacity(0.4))
                row("Sunrise", timeline.sunrise)
            }

            if let c = report.conditions {
                card {
                    Text("Sky at sunset").font(.headline)
                    value("High cloud", "\(c.highCloud)%")
                    value("Mid cloud", "\(c.midCloud)%")
                    value("Low cloud", "\(c.lowCloud)%")
                    value("Low cloud toward sunset", c.horizonLowCloud.map { "\($0)%" } ?? "—")
                    value("Chance of rain", "\(c.rainChance)%")
                    value("Visibility", String(format: "%.0f km", c.visibilityKm))
                    Divider().overlay(.white.opacity(0.4))
                    value("Night type (debug)", report.verdict.night?.rawValue ?? "—")
                }
            }

            card {
                Text("Did you know?").font(.headline)
                Text(FunFacts.fact(for: timeline.sunset))
            }
        }
        .foregroundStyle(.white)
        .padding(24)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10, content: content)
            .font(.callout)
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.15), in: .rect(cornerRadius: 16))
    }

    /// Times shown in the location's own time zone.
    private func timeString(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: report.timeZone))
    }

    private func row(_ label: String, _ date: Date?) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(date.map(timeString) ?? "—").monospacedDigit()
        }
    }

    private func value(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).monospacedDigit()
        }
    }
}

/// An arrow that points toward where the sun will set.
/// Without a compass (e.g. the Simulator) it points as if the phone faces north.
private struct SunCompass: View {
    let sunsetAzimuth: Double
    let heading: Double?

    /// Kept continuous (can go past 360) so the arrow never spins the long way round.
    @State private var angle: Double = 0

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .strokeBorder(.white.opacity(0.4), lineWidth: 2)
                Image(systemName: "sun.horizon.fill")
                    .font(.system(size: 36))
                    .offset(y: -58)
                    .rotationEffect(.degrees(angle))
                Image(systemName: "location.north.fill")
                    .font(.system(size: 40))
                    .rotationEffect(.degrees(angle))
            }
            .frame(width: 160, height: 160)
            .animation(.interpolatingSpring(stiffness: 60, damping: 12), value: angle)

            Text("Face \(SunCalculator.compassPoint(for: sunsetAzimuth)) · \(Int(sunsetAzimuth.rounded()))°")
                .font(.headline)
            if heading == nil {
                Text("No compass available: arrow assumes the phone faces north")
                    .font(.caption)
                    .opacity(0.7)
            }
        }
        .onAppear { angle = target }
        .onChange(of: target) { _, newTarget in
            // Move by the shortest way round the circle.
            let delta = (newTarget - angle).truncatingRemainder(dividingBy: 360)
            angle += delta > 180 ? delta - 360 : (delta < -180 ? delta + 360 : delta)
        }
    }

    private var target: Double { sunsetAzimuth - (heading ?? 0) }
}

#Preview {
    ContentView()
}
