//
//  NotificationViewController.swift
//  SunsetNotification
//
//  The press-and-hold view for the evening notification.
//  It loads tonight's conditions live, so it's never stale.
//  Placeholder layout; the real design comes from Figma.
//

import SwiftUI
import UIKit
import UserNotifications
import UserNotificationsUI

final class NotificationViewController: UIViewController, UNNotificationContentExtension {
    private var host: UIHostingController<NotificationPreview>?

    func didReceive(_ notification: UNNotification) {
        let info = notification.request.content.userInfo
        guard let latitude = info["latitude"] as? Double,
              let longitude = info["longitude"] as? Double else { return }

        let preview = NotificationPreview(latitude: latitude, longitude: longitude,
                                          placeName: info["placeName"] as? String)
        let host = UIHostingController(rootView: preview)
        host.view.backgroundColor = .clear
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
        self.host = host
    }
}

struct NotificationPreview: View {
    let latitude: Double
    let longitude: Double
    let placeName: String?

    @State private var forecast = ForecastModel()

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.12, green: 0.14, blue: 0.32),
                                    Color(red: 0.85, green: 0.42, blue: 0.30)],
                           startPoint: .top, endPoint: .bottom)

            switch forecast.state {
            case .idle, .loading:
                ProgressView("Checking tonight's sky…")
                    .tint(.white)
            case .noSunset:
                Text("No sunset here today.")
            case .loaded(let report, let forecastFailed):
                details(report, forecastFailed: forecastFailed)
            }
        }
        .foregroundStyle(.white)
        .task { await forecast.load(latitude: latitude, longitude: longitude) }
    }

    private func details(_ report: SunsetReport, forecastFailed: Bool) -> some View {
        let time = report.timeline.sunset.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened, timeZone: report.timeZone))
        let direction = SunCalculator.compassPoint(for: report.timeline.sunsetAzimuth)

        return VStack(alignment: .leading, spacing: 10) {
            Text(report.verdict.headline)
                .font(.title3.bold())
            if let stepOut = report.verdict.stepOutLine {
                Text(stepOut)
            }
            Text("Sunset \(time) · face \(direction)" + (placeName.map { " · \($0)" } ?? ""))
                .font(.subheadline)
                .opacity(0.85)
            if let c = report.conditions {
                Text("Clouds: high \(c.highCloud)%, mid \(c.midCloud)%, low \(c.lowCloud)% · Rain \(c.rainChance)%")
                    .font(.caption)
                    .opacity(0.75)
            } else if forecastFailed {
                Text("Couldn't load the latest forecast.")
                    .font(.caption)
                    .opacity(0.75)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
