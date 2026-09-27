//
//  LocationPicker.swift
//  sunset
//
//  "Change location": current location, or a zip code or town with an optional radius.
//  Used as its own sheet and inside Settings.
//

import SwiftUI

struct LocationPicker: View {
    @Bindable var settings: Settings
    let location: LocationManager

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var radiusKm: Double?
    @State private var results: [Place] = []
    @State private var isSearching = false
    @State private var hasSearched = false

    var body: some View {
        List {
            Section {
                Button("Use my current location", systemImage: "location.fill") {
                    settings.locationChoice = .current
                    location.requestLocation()
                    dismiss()
                }
                if location.isDenied {
                    Text("Location access is off for Sunset app. Turn it on in Settings, or pick a place below.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Or pick a place") {
                TextField("Zip code or town", text: $query)
                    .textContentType(.addressCityAndState)
                    .submitLabel(.search)
                    .onSubmit { Task { await search() } }
                Picker("Area", selection: $radiusKm) {
                    Text("Exact spot").tag(Double?.none)
                    Text("Within 5 km").tag(Double?.some(5))
                    Text("Within 25 km").tag(Double?.some(25))
                }
            }

            if isSearching {
                ProgressView()
            } else if !results.isEmpty {
                Section("Results") {
                    ForEach(results.indices, id: \.self) { index in
                        Button(results[index].name) { choose(results[index]) }
                    }
                }
            } else if hasSearched {
                Text("No matches. Try a zip code, or a town and state.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Change location")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    private func search() async {
        isSearching = true
        results = await PlaceSearch.search(query)
        isSearching = false
        hasSearched = true
    }

    private func choose(_ place: Place) {
        var chosen = place
        chosen.radiusKm = radiusKm
        settings.locationChoice = .manual(chosen)
        location.stopUsingLocation()
        dismiss()
    }
}
