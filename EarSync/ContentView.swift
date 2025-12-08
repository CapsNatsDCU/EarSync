//
//  ContentView.swift
//  EarSync
//
//  Created by Josiah Lenowitz on 3/4/25.
//

//Josiah is oldest and caleb is our team baby
import SwiftUI
import SwiftData
import Translation

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

    var body: some View {
        NavigationStack {
            List {
                ForEach(items) { item in
                    NavigationLink {
                        TranslationView(item: item)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            // Primary: timestamp
                            Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                                .font(.headline)

                            // Secondary: preview of the most recent original text, if available
                            if let last = item.conversation.last {
                                let preview = last.originalText.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !preview.isEmpty {
                                    Text(preview.count > 60 ? String(preview.prefix(60)) + "…" : preview)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Chat history")
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
