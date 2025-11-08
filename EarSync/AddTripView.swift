import SwiftUI

struct AddTripView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var destination: String = ""
    @State private var date: Date = .now

    // Callback to send data back to the calendar view
    let onSave: (String, Date) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Destination") {
                    TextField("Berlin, Germany", text: $destination)
                        .textInputAutocapitalization(.words)
                }

                Section("Date") {
                    DatePicker("Trip date", selection: $date, displayedComponents: .date)
                }
            }
            .navigationTitle("New Trip")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = destination.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }

                        onSave(trimmed, date)
                        dismiss()
                    }
                }
            }
        }
    }
}
