//
//  SettingsView.swift
//  EarSync
//
//  Created by Matthew Shaffer on 11/8/25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("smartDownloadEnabled") private var smartDownloadEnabled = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Downloads") {
                    Toggle("Enable smart downloads", isOn: $smartDownloadEnabled)
                }

                Section("Account") {
                    Text("Signed in as: (later)")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
