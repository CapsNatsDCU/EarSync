//
//  HomeView.swift
//  EarSync
//
//  Created by Matthew Shaffer 11/08/25
//

import SwiftUI

struct HomeView: View {
    // Remember user’s last choice across launches
    @AppStorage("currentScenarioMode") private var currentScenarioMode: String = ScenarioMode.tourist.rawValue
    @State private var showModePicker = false

    // Sheets/modals for all features
    @State private var showPhrasebook = false
    @State private var showCalendar = false
    @State private var showTranslate = false
    @State private var showCamera = false
    @State private var showPronunciation = false
    @State private var showSync = false

    // Temporary item used when we show TranslationView in a sheet
    @State private var tempItem = Item(timestamp: Date())

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    Text("Choose how you want to use EarSync")
                        .font(.title2.bold())
                        .padding(.top, 8)

                    // Current mode card
                    Button {
                        withAnimation(.spring) {
                            showModePicker.toggle()
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Current mode")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(selectedMode.title)
                                    .font(.title3.bold())
                                Text(selectedMode.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            Image(systemName: showModePicker ? "chevron.up" : "chevron.down")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.secondarySystemBackground))
                        )
                    }
                    .buttonStyle(.plain)

                    // Expanded list of all modes
                    if showModePicker {
                        VStack(spacing: 10) {
                            ForEach(ScenarioMode.allCases) { mode in
                                Button {
                                    currentScenarioMode = mode.rawValue
                                    withAnimation(.spring) {
                                        showModePicker = false
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: mode.systemImage)
                                        Text(mode.title)
                                        Spacer()
                                        if mode == selectedMode {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.green)
                                        }
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color(.systemBackground))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Actions section
                    ModeActionsView(
                        mode: selectedMode,
                        showPhrasebook: $showPhrasebook,
                        showCalendar: $showCalendar,
                        showTranslate: $showTranslate,
                        showCamera: $showCamera,
                        showPronunciation: $showPronunciation,
                        showSync: $showSync
                    )

                    Spacer(minLength: 30)
                }
                .padding(.horizontal)
            }
            .navigationTitle("EarSync")
            // Sheets for all features
            .sheet(isPresented: $showPhrasebook) {
                NavigationStack {
                    PhrasebookView(p: Phrasebook())
                        .navigationTitle("Phrasebook")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            .sheet(isPresented: $showCalendar) {
                NavigationStack {
                    TravelCalendarView()
                        .navigationTitle("Travel calendar")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            .sheet(isPresented: $showTranslate) {
                NavigationStack {
                    TranslationView(item: tempItem)
                        .navigationTitle("Live translation")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            .sheet(isPresented: $showCamera) {
                NavigationStack {
                    VisualTranslationView()
                        .navigationTitle("Camera translate")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            .sheet(isPresented: $showPronunciation) {
                NavigationStack {
                    PronunciationTrainingView()
                        .navigationTitle("Pronunciation")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            .sheet(isPresented: $showSync) {
                NavigationStack {
                    SyncSessionView()
                        .navigationTitle("Sync session")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
    }

    private var selectedMode: ScenarioMode {
        ScenarioMode(rawValue: currentScenarioMode) ?? .tourist
    }
}

// MARK: - Actions list

struct ModeActionsView: View {
    let mode: ScenarioMode
    @Binding var showPhrasebook: Bool
    @Binding var showCalendar: Bool
    @Binding var showTranslate: Bool
    @Binding var showCamera: Bool
    @Binding var showPronunciation: Bool
    @Binding var showSync: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What do you want to do?")
                .font(.headline)

            // ------------------------------------------------
            // Shared actions shown for every scenario
            // If your team wants to remove something globally,
            // remove it from this shared block.
            // ------------------------------------------------
            ActionRow(title: "Open phrasebook", systemImage: "books.vertical") {
                showPhrasebook = true
            }
            ActionRow(title: "Start live translation", systemImage: "waveform") {
                showTranslate = true
            }
            ActionRow(title: "Camera / visual translate", systemImage: "camera.viewfinder") {
                showCamera = true
            }
            ActionRow(title: "Travel calendar (pre-travel)", systemImage: "calendar") {
                showCalendar = true
            }
            ActionRow(title: "Pronunciation training", systemImage: "mic") {
                showPronunciation = true
            }
            ActionRow(title: "Sync / connect to EarSync devices", systemImage: "person.2.wave.2") {
                showSync = true
            }

            // ------------------------------------------------
            // Scenario-specific extras
            // This is where you add/remove items per mode.
            // ------------------------------------------------
            switch mode {
            case .tourist:
                ActionRow(title: "Tourist tips", systemImage: "mappin") {
                    // later: tourist specific view
                }

            case .preTravel:
                ActionRow(title: "Enable smart download", systemImage: "arrow.down.circle") {
                    // later: toggle in settings/AppStorage
                }

            case .sync:
                ActionRow(title: "Manage current session", systemImage: "person.2") {
                    // later: manage session view
                }

            case .observer:
                ActionRow(title: "Ambient listening options", systemImage: "ear.badge.waveform") {
                    // later
                }

            case .simple:
                ActionRow(title: "Quick phrase list", systemImage: "list.bullet") {
                    // later
                }
            }
        }
    }
}

// MARK: - Row view

struct ActionRow: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                    .frame(width: 28)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Placeholder views for features not built yet

struct PronunciationTrainingView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Pronunciation training")
                .font(.title2.bold())
            Text("This is a placeholder. Later this can record the user, compare to Spanish, and give feedback.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

struct SyncSessionView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Sync session")
                .font(.title2.bold())
            Text("This is a placeholder. Later this can discover nearby EarSync devices and join a shared session.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
