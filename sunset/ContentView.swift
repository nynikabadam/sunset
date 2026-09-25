//
//  ContentView.swift
//  sunset
//
//  Day 1 test screen: today's sunset time and direction from your location.
//  Placeholder layout; the real design comes from Figma.
//

import SwiftUI
import CoreLocation

struct ContentView: View {
    @State private var location = LocationManager()

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.12, green: 0.14, blue: 0.32),
                                    Color(red: 0.85, green: 0.42, blue: 0.30),
                                    Color(red: 0.98, green: 0.76, blue: 0.45)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            switch location.status {
            case .notAsked:
                askForLocation
            case .denied:
                message("Location is off", detail: "Turn it on in Settings → Privacy → Location Services to see your sunset. (Pin drop coming later.)")
            case .locating:
                ProgressView("Finding you…").tint(.white).foregroundStyle(.white)
            case .located:
                if let coordinate = location.coordinate {
                    SunsetDetails(coordinate: coordinate, heading: location.heading)
                }
            }
        }
    }

    private var askForLocation: some View {
        VStack(spacing: 16) {
            Text("When's the sunset?")
                .font(.largeTitle.bold())
            Text("Sunset app uses your location to work out when the sun sets and which way to look.")
                .multilineTextAlignment(.center)
                .opacity(0.85)
            Button("Use my location") { location.requestLocation() }
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.25))
        }
        .foregroundStyle(.white)
        .padding(32)
    }

    private func message(_ title: String, detail: String) -> some View {
        VStack(spacing: 12) {
            Text(title).font(.title2.bold())
            Text(detail).multilineTextAlignment(.center).opacity(0.85)
        }
        .foregroundStyle(.white)
        .padding(32)
    }
}

private struct SunsetDetails: View {
    let coordinate: CLLocationCoordinate2D
    let heading: Double?

    var body: some View {
        if let timeline = SunCalculator.timeline(on: .now, latitude: coordinate.latitude, longitude: coordinate.longitude) {
            VStack(spacing: 28) {
                VStack(spacing: 4) {
                    Text("Sunset")
                        .font(.headline)
                        .opacity(0.8)
                    Text(timeline.sunset, style: .time)
                        .font(.system(size: 64, weight: .semibold, design: .rounded))
                }

                SunCompass(sunsetAzimuth: timeline.sunsetAzimuth, heading: heading)

                VStack(alignment: .leading, spacing: 10) {
                    row("Golden hour starts", timeline.goldenHourStart)
                    row("Sunset", timeline.sunset)
                    row("Blue hour starts", timeline.blueHourStart)
                    row("Blue hour ends", timeline.blueHourEnd)
                    Divider().overlay(.white.opacity(0.4))
                    row("Sunrise", timeline.sunrise)
                }
                .font(.callout)
                .padding(20)
                .background(.white.opacity(0.15), in: .rect(cornerRadius: 16))

                Text(String(format: "%.3f, %.3f", coordinate.latitude, coordinate.longitude))
                    .font(.caption.monospacedDigit())
                    .opacity(0.6)
            }
            .foregroundStyle(.white)
            .padding(24)
        } else {
            Text("The sun doesn't set here today.")
                .font(.title3.bold())
                .foregroundStyle(.white)
        }
    }

    private func row(_ label: String, _ date: Date?) -> some View {
        HStack {
            Text(label)
            Spacer()
            if let date {
                Text(date, style: .time).monospacedDigit()
            } else {
                Text("—")
            }
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
