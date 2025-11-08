//
//  TravelCalendarView.swift
//  EarSync
//
//  Created by Matthew Shaffer on 11/8/25.
//

import SwiftUI

struct TravelCalendarView: View {
    // Start with an empty list; user will add trips
    @State private var trips: [Trip] = []

    // Controls sheet presentation
    @State private var showingAddTrip = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(trips) { trip in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(trip.destination)
                                .font(.headline)

                            Text(trip.date, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            // Show what language we think they should practice
                            Text("Practice: \(trip.practiceLanguage)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Toggle("Smart", isOn: binding(for: trip))
                            .labelsHidden()
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Travel Calendar")
            .toolbar {
                Button {
                    showingAddTrip = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showingAddTrip) {
                AddTripView { destination, date in
                    // Figure out which language they should prep for
                    let lang = CityLanguageDB.language(for: destination)

                    let newTrip = Trip(
                        destination: destination,
                        date: date,
                        smartDownload: true,
                        practiceLanguage: lang
                    )
                    trips.append(newTrip)
                }
            }
        }
    }

    // Create a binding to the specific trip's smartDownload
    private func binding(for trip: Trip) -> Binding<Bool> {
        Binding {
            trips.first(where: { $0.id == trip.id })?.smartDownload ?? false
        } set: { newValue in
            if let idx = trips.firstIndex(where: { $0.id == trip.id }) {
                trips[idx].smartDownload = newValue
            }
        }
    }
}

// Updated Trip model to include the language we detected
struct Trip: Identifiable {
    let id = UUID()
    var destination: String
    var date: Date
    var smartDownload: Bool
    var practiceLanguage: String
}
