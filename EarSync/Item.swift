//
//  Item.swift
//  EarSync
//
//  Created by Josiah Lenowitz on 3/4/25.
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class Item: Identifiable {
    var timestamp: Date
    @Relationship(deleteRule: .cascade) var conversation: [ConversationPart] = []
    
    init(timestamp: Date) {
        self.timestamp = timestamp
        self.conversation = []
    }
    
    @MainActor
    func appendPart(_ message: String) async {
        let ot = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ot.isEmpty else { return }

        // Create a new conversation part with placeholder translated text.
        let part = ConversationPart(originalText: ot, translatedText: "")

        // Append it to this item's conversation so SwiftData can track and update it.
        self.conversation.append(part)

        // Use the new, context-aware AI pass when available.
        if #available(iOS 26, *) {
            await callToAINew(c: part)
        } else {
            // Fallback: just echo the original text if the new API isn't available.
            part.translatedText = ot
        }
    }
}

@Model
class ConversationPart: Codable, Identifiable {
    var originalText: String
    var translatedText: String
    var isSaved: Bool = false
    var latitude: Double?
    var longitude: Double?
    var locationDescription: String?
    var setting: String?

    init(originalText: String, translatedText: String) {
        self.originalText = originalText
        self.translatedText = translatedText
    }

    @MainActor
    func setLocationOnce(_ loc: CLLocation) {
        guard latitude == nil && longitude == nil else { return }
        latitude = loc.coordinate.latitude
        longitude = loc.coordinate.longitude
    }

    @Transient
    var location: CLLocation? {
        get {
            guard let lat = latitude, let lon = longitude else { return nil }
            return CLLocation(latitude: lat, longitude: lon)
        }
    }

    enum CodingKeys: String, CodingKey {
        case originalText
        case translatedText
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.originalText = try container.decode(String.self, forKey: .originalText)
        self.translatedText = try container.decode(String.self, forKey: .translatedText)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(originalText, forKey: .originalText)
        try container.encode(translatedText, forKey: .translatedText)
    }
    
    func updateLocation(_ loc: CLLocation) {
        latitude = loc.coordinate.latitude
        longitude = loc.coordinate.longitude
    }
    
    init(text: String) async {
        originalText = text
        translatedText = await simpleTranslate(text: text)
    }

}

@Model
final class Phrasebook: Codable, Identifiable {
    var bookID = UUID()
    var userLan: String = "en"
    var speakerLan: String = "es"
    var phrases: [Phrase] = []
    var targetRegon: String?

    init(userLan: String = "en") {
        self.userLan = userLan
    }

    enum CodingKeys: String, CodingKey {
        case userLan
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.userLan = try container.decode(String.self, forKey: .userLan)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userLan, forKey: .userLan)
    }
    
    func addPhrase(_ p: Phrase) {
        phrases.append(p)
    }
}

@Model
final class Phrase: Identifiable {
    var phraseID: UUID = UUID()
    
    var usrLanText: String
    var transText: String
    
    init(usrLanText: String, transText: String) {
        self.usrLanText = usrLanText
        self.transText = transText
    }
    
    init(c: ConversationPart) {
        self.usrLanText = c.originalText
        self.transText = c.translatedText
    }
    
    init(text: String) async {
        self.usrLanText = text
        self.transText = await simpleTranslate(text: text)
    }
}

// Updated Trip model to include the language we detected
@Model
final class Trip: Identifiable {
    var id = UUID()
    var destination: String
    var date: Date
    var smartDownload: Bool
    var practiceLanguage: String
    
    init(destination: String, date: Date, smartDownload: Bool, practiceLanguage: String) {
        self.destination = destination
        self.date = date
        self.smartDownload = smartDownload
        self.practiceLanguage = practiceLanguage
    }
}

struct SentenceContext {
    var previousSource: String?      // last full sentence in source language
    var previousTarget: String?      // last full sentence in target language

    var currentSource: String        // current sentence we’re building in source
    var currentTarget: String?       // current translation for that sentence
}
