//
//  SettingsSheet.swift
//  sunset
//
//  Notifications on or off, change location, and a few testing tools.
//  Placeholder layout; the real design comes from Figma.
//

import SwiftUI
import UserNotifications

struct SettingsSheet: View {
    @Bindable var settings: Settings
    let location: LocationManager
    let notificationStatus: UNAuthorizationStatus
    let placeName: String?
    let onSendTest: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Sunset heads-up", isOn: notificationsBinding)
                        .disabled(notificationStatus == .denied)
                } header: {
                    Text("Notifications")
                } footer: {
                    if notificationStatus == .denied {
                        Text("Notifications are off for Sunset app. Turn them on in the iOS Settings app.")
                    } else {
                        Text("\(Settings.notifyMinutesBefore) minutes before sunset, every evening.")
                    }
                }

                Section("Location") {
                    LabeledContent("Showing", value: placeName ?? "—")
                    NavigationLink("Change location") {
                        LocationPicker(settings: settings, location: location)
                    }
                }

                Section {
                    Button("Send a test notification in 5 seconds", action: onSendTest)
                    Button("Reset to first launch", role: .destructive) { settings.reset() }
                } header: {
                    Text("Testing")
                } footer: {
                    Text("After tapping, lock your phone or go to the Home Screen. When the notification arrives, press and hold it.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    /// Turning it on asks iOS for permission the first time.
    private var notificationsBinding: Binding<Bool> {
        Binding {
            settings.notificationsOn
        } set: { on in
            settings.notificationCardAnswered = true
            if on {
                Task { settings.notificationsOn = await NotificationScheduler.requestPermission() }
            } else {
                settings.notificationsOn = false
            }
        }
    }
}
