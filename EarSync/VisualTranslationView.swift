//
//  HomeTabView.swift
//  EarSync
//
//  Created by Josiah Lenowitz on 10/29/25.
//

import SwiftUI

struct HomeTabView: View {
    var body: some View {
        TabView {
            TranslationView(item: Item(timestamp: .now))
                .padding(.vertical)
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            ContentView()
                .padding(.vertical)
                .tabItem {
                    Label("Converstion Hisotry", systemImage: "bubble.left.and.bubble.right")
                }

            PhrasebookView(p: Phrasebook())
                .tabItem {
                    Label("Phrasebook", systemImage: "books.vertical")
                }
            
            VisualTranslationView()
                .tabItem{
                    Label("cam model", systemImage: "camera")
                }
        }
    }
}

#Preview {
    HomeTabView()
}
