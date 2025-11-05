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

        let tt = await callToAIAsync(text: ot)
        let part = ConversationPart(originalText: ot, translatedText: tt)
        self.conversation.append(part)
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
    
    init(text: String) async {
        originalText = text
        translatedText = await callToAIAsync(text: text)
    }

}

@Model
final class Phrasebook: Codable, Identifiable {
    var bookID = UUID()
    var userLan: String = "en"
    var speakerLan: String = "es"
    var phrases: [Phrase] = []

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
        self.transText = await callToAIAsync(text: text)
    }
}
