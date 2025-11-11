//
//  SettingsView.swift
//  EarSync
//
//  Created by Matthew Shaffer on 11/8/25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("smartDownloadEnabled") private var smartDownloadEnabled = false
    @AppStorage("demoMode") private var demoMode = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Downloads") {
                    Toggle("Enable smart downloads", isOn: $smartDownloadEnabled)
                }
                
                Section("Demo Mode") {
                    Toggle("Enable Demo Mode", isOn: $demoMode)
                }

                Section("Account") {
                    Text("Signed in as: (later)")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
