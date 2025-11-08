//  ScenarioMode.swift
//  EarSync

import Foundation

/// The different ways the app can run / focus.
enum ScenarioMode: String, CaseIterable, Identifiable {
    case tourist
    case sync
    case observer
    case simple
    case preTravel    // 👈 new

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tourist: return "Tourist mode"
        case .sync: return "Sync mode"
        case .observer: return "Observer mode"
        case .simple: return "Simple translation"
        case .preTravel: return "Pre-travel"
        }
    }

    var subtitle: String {
        switch self {
        case .tourist:
            return "Learn local phrases, accent tips, and use it as a travel helper."
        case .sync:
            return "Connect to other EarSync devices and share a conversation log."
        case .observer:
            return "Translate what is happening around you without talking."
        case .simple:
            return "Speak and broadcast your sentence in a chosen language."
        case .preTravel:
            return "Plan trips, download languages, and practice before you go."
        }
    }

    var systemImage: String {
        switch self {
        case .tourist: return "mappin.and.ellipse"
        case .sync: return "person.2.wave.2"
        case .observer: return "eye"
        case .simple: return "mic.and.signal.meter"
        case .preTravel: return "airplane.departure"
        }
    }
}
