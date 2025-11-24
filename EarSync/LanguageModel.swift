//
//  LanguageModel.swift
//  EarSync
//
//  Created by Matthew Shaffer on 11/24/25.
//
import Foundation

struct LanguageItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let bcp47: String
}

enum LanguageCatalog {
    static let common: [LanguageItem] = [
        .init(name: "English",       bcp47: "en"),
        .init(name: "Spanish",       bcp47: "es"),
        .init(name: "German",        bcp47: "de"),
        .init(name: "French",        bcp47: "fr"),
        .init(name: "Italian",       bcp47: "it"),
        .init(name: "Portuguese",    bcp47: "pt"),
        .init(name: "Dutch",         bcp47: "nl"),
        .init(name: "Turkish",       bcp47: "tr"),
        .init(name: "Arabic",        bcp47: "ar"),
        .init(name: "Chinese (Simplified)", bcp47: "zh-Hans"),
        .init(name: "Chinese (Traditional)", bcp47: "zh-Hant"),
        .init(name: "Japanese",      bcp47: "ja"),
        .init(name: "Korean",        bcp47: "ko"),
        .init(name: "Thai",          bcp47: "th"),
        .init(name: "Vietnamese",    bcp47: "vi")
    ]
}
