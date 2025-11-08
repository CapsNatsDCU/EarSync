// CityLanguageDB.swift
// Simple local lookup for destination -> primary language
// You can expand or override this as needed.

import Foundation

struct CityLanguageDB {

    // Key is lowercased city name (optionally with country), value is BCP-47 language code-ish string.
    // Keep these lowercased so lookup is easy.
    private static let table: [String: String] = [
        // Europe
        "berlin": "German",
        "munich": "German",
        "hamburg": "German",
        "frankfurt": "German",
        "paris": "French",
        "lyon": "French",
        "marseille": "French",
        "london": "English",
        "manchester": "English",
        "edinburgh": "English",
        "dublin": "English",
        "madrid": "Spanish",
        "barcelona": "Spanish",
        "valencia": "Spanish",
        "sevilla": "Spanish",
        "rome": "Italian",
        "milan": "Italian",
        "florence": "Italian",
        "naples": "Italian",
        "amsterdam": "Dutch",
        "rotterdam": "Dutch",
        "brussels": "French",
        "antwerp": "Dutch",
        "vienna": "German",
        "zurich": "German",
        "geneva": "French",
        "copenhagen": "Danish",
        "stockholm": "Swedish",
        "oslo": "Norwegian",
        "helsinki": "Finnish",
        "lisbon": "Portuguese",
        "porto": "Portuguese",
        "prague": "Czech",
        "budapest": "Hungarian",
        "warsaw": "Polish",
        "krakow": "Polish",
        "athens": "Greek",
        "istanbul": "Turkish",

        // North America
        "new york": "English",
        "los angeles": "English",
        "san francisco": "English",
        "seattle": "English",
        "chicago": "English",
        "houston": "English",
        "miami": "English",
        "vancouver": "English",
        "toronto": "English",
        "montreal": "French",
        "mexico city": "Spanish",
        "cancun": "Spanish",

        // Latin America
        "bogota": "Spanish",
        "lima": "Spanish",
        "santiago": "Spanish",
        "buenos aires": "Spanish",
        "montevideo": "Spanish",
        "quito": "Spanish",
        "panama city": "Spanish",
        "sao paulo": "Portuguese",
        "rio de janeiro": "Portuguese",
        "salvador": "Portuguese",

        // Middle East / Africa
        "dubai": "Arabic",
        "abu dhabi": "Arabic",
        "doha": "Arabic",
        "riyadh": "Arabic",
        "jeddah": "Arabic",
        "cairo": "Arabic",
        "casablanca": "Arabic",
        "johannesburg": "English",
        "cape town": "English",
        "nairobi": "English",

        // Asia
        "tokyo": "Japanese",
        "osaka": "Japanese",
        "kyoto": "Japanese",
        "seoul": "Korean",
        "busan": "Korean",
        "beijing": "Chinese",
        "shanghai": "Chinese",
        "shenzhen": "Chinese",
        "guangzhou": "Chinese",
        "hong kong": "Chinese",
        "taipei": "Chinese",
        "bangkok": "Thai",
        "phuket": "Thai",
        "singapore": "English",
        "kuala lumpur": "Malay",
        "jakarta": "Indonesian",
        "bali": "Indonesian",
        "manila": "Filipino",
        "hanoi": "Vietnamese",
        "ho chi minh city": "Vietnamese",
        "delhi": "Hindi",
        "new delhi": "Hindi",
        "mumbai": "Hindi",
        "bengaluru": "Kannada",
        "bangalore": "Kannada",
        "chennai": "Tamil",
        "hyderabad": "Telugu",

        // Oceania
        "sydney": "English",
        "melbourne": "English",
        "auckland": "English"
    ]

    /// Attempts to extract a city name from a user-entered destination string
    /// e.g. "Berlin, Germany" -> "berlin"
    private static func normalizedKey(from destination: String) -> String {
        let lower = destination.lowercased()
        // take just the first component before comma
        if let first = lower.split(separator: ",").first {
            return String(first).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return lower.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func language(for destination: String) -> String {
        let key = normalizedKey(from: destination)
        if let lang = table[key] {
            return lang
        }
        // fallback if unknown
        return "Spanish"
    }
}
