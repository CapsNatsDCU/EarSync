//
//  HomeTabView.swift
//  EarSync
//

import SwiftUI
import SwiftData

struct HomeTabView: View {
    @State private var selectedTab: BottomTab = .home

    var body: some View {
        ZStack(alignment: .bottom) {
            // main content
            Group {
                switch selectedTab {
                case .home:
                    NavigationStack {
                        HomeView()
                    }
                case .settings:
                    NavigationStack {
                        SettingsView()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))

            // glassy bottom bar
            HStack(spacing: 18) {
                GlassTabButton(
                    icon: "house",
                    isSelected: selectedTab == .home
                ) {
                    selectedTab = .home
                }

                GlassTabButton(
                    icon: "gearshape",
                    isSelected: selectedTab == .settings
                ) {
                    selectedTab = .settings
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
            .padding(.bottom, 14)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    enum BottomTab {
        case home
        case settings
    }
}

private struct GlassTabButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(isSelected ? Color.accentColor : Color.secondary)
                .frame(width: 40, height: 34)
                .background(
                    Circle()
                        .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeTabView()
        .modelContainer(for: Item.self, inMemory: true)
}
