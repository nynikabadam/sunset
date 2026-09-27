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
import os

/// Filter Console.app by "sunsetnotif" to see these.
private let log = Logger(subsystem: "badam.sunset.sunsetnotif", category: "sunsetnotif")

/// A fixed Objective-C name, so iOS finds this class from the extension's Info.plist
/// (NSExtensionPrincipalClass) without depending on the module name.
@objc(NotificationViewController)
final class NotificationViewController: UIViewController, UNNotificationContentExtension {
    private let host = UIHostingController(rootView: NotificationPreview(place: nil))

    override func viewDidLoad() {
        super.viewDidLoad()
        log.notice("sunsetnotif: viewDidLoad, bounds \(self.view.bounds.debugDescription, privacy: .public)")
        preferredContentSize = CGSize(width: view.bounds.width, height: 240)

        // Shown right away, pinned to the edges, so there's never a blank box.
        addChild(host)
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)
    }

    func didReceive(_ notification: UNNotification) {
        let info = notification.request.content.userInfo
        log.notice("sunsetnotif: didReceive, userInfo \(String(describing: info), privacy: .public)")
        let place = NotificationPreview.Place(
            latitude: Self.number(info["latitude"]),
            longitude: Self.number(info["longitude"]),
            name: (info["placeName"] as? String).flatMap { $0.isEmpty ? nil : $0 })
        host.rootView = NotificationPreview(place: place)
    }

    /// userInfo numbers can arrive as Double, NSNumber or String.
    private static func number(_ value: Any?) -> Double? {
        switch value {
        case let d as Double: return d
        case let n as NSNumber: return n.doubleValue
        case let s as String: return Double(s)
        default: return nil
        }
    }
}

struct NotificationPreview: View {
    struct Place: Equatable {
        let latitude: Double?
        let longitude: Double?
        let name: String?
    }

    /// Nil until the notification arrives.
    let place: Place?

    @State private var forecast = ForecastModel()

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.12, green: 0.14, blue: 0.32),
                                    Color(red: 0.85, green: 0.42, blue: 0.30)],
                           startPoint: .top, endPoint: .bottom)
            content
        }
        .foregroundStyle(.white)
        .task(id: place) {
            guard let latitude = place?.latitude, let longitude = place?.longitude else { return }
            await forecast.load(latitude: latitude, longitude: longitude)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let place, place.latitude == nil || place.longitude == nil {
            Text("Couldn't read this notification's location. Open the app to see tonight's sunset.")
                .multilineTextAlignment(.center)
                .padding(20)
        } else {
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
            Text("Sunset \(time) · face \(direction)" + (place?.name.map { " · \($0)" } ?? ""))
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
