//
//  SettingsView.swift
//  EarSync
//
//  Created by Matthew Shaffer on 11/8/25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("smartDownloadEnabled") private var smartDownloadEnabled = true
    @AppStorage("demoMode") private var demoMode = false
    @AppStorage("proMode") private var proMode = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Downloads") {
                    Toggle("Enable smart downloads", isOn: $smartDownloadEnabled)
                }
                
                Section("Demo Mode") {
                    Toggle("Enable Demo Mode", isOn: $demoMode)
                }
                
                Section("Pro Mode") {
                    Toggle("Enable Pro Mode ($$)", isOn: $proMode)
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
