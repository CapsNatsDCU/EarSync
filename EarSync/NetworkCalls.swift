//
//  NetworkCalls.swift
//  EarSync
//
//  Created by Josiah Lenowitz on 5/16/25.
//

import Foundation
import Translation
import NaturalLanguage
import AVFoundation

private let sharedSynth = AVSpeechSynthesizer()

/// New async API — does the work off the main actor and returns a result you can `await`.
@available(iOS 26, *)
func callToAIAsync(text: String) async -> String {
    let demoMode = UserDefaults.standard.bool(forKey: "demoMode")
    print(text)
    let detected = await languageDetection(text: text)
    let direction = detectENorES(from: text)
    let targetLang = (direction == "es") ? "en" : "es"
    print("[debug] translating from \(detected) to \(targetLang)")
    if demoMode {
        do {
            let installedSource = Locale.Language(identifier: detected)
            let target = Locale.Language(identifier: targetLang)
            let session = TranslationSession(installedSource: installedSource, target: target)
            let result = try await session.translate(text).targetText
            print("result ", result)
            return result
        } catch {
            return text
        }
    } else {
        //do somthing
        //speciffically start the ai pass
    }
}

/// Legacy sync API — kept for compatibility; prefer `callToAIAsync`.
@available(iOS 26, *)
func languageDetection(text: String) async -> String {
    // Use NaturalLanguage to detect dominant language; returns BCP-47 like "en", "es"
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "unknown" }
    let recognizer = NLLanguageRecognizer()
    recognizer.processString(trimmed)
    if let lang = recognizer.dominantLanguage {
        return lang.rawValue
    } else {
        return "unknown"
    }
}

func speekText(text: String) {
    // Speak the provided text using AVSpeechSynthesizer
    // Uses a shared synthesizer to persist across calls and avoid deallocation mid-utterance.
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    
    // Configure audio session for playback to route through speaker
    let session = AVAudioSession.sharedInstance()
    do {
        try session.setCategory(.playback, mode: .default, options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    } catch {
        print("[audio] Failed to configure AVAudioSession for playback: \(error)")
    }
    
    // Detect English or Spanish and pick the best regional voice available.
    let enOrEs = detectENorES(from: trimmed)
    let utterance = AVSpeechUtterance(string: trimmed)
    if let voice = bestVoiceForENorES(enOrEs) {
        utterance.voice = voice
    }
    utterance.rate = AVSpeechUtteranceDefaultSpeechRate
    if utterance.voice?.language.hasPrefix("es") == true {
        // Spanish TTS often sounds more natural slightly slower.
        utterance.rate = max(AVSpeechUtteranceDefaultSpeechRate - 0.05, 0.1)
    }
    utterance.pitchMultiplier = 1.0
    utterance.volume = 1.0
    
    // Speak on the main thread to align with UI run loop expectations.
    DispatchQueue.main.async {
        sharedSynth.stopSpeaking(at: .immediate)
        sharedSynth.speak(utterance)
    }
    
}

/// Detect "en" or "es" for the given text. Default to "en".
private func detectENorES(from text: String) -> String {
    if #available(iOS 26, *) {
        let r = NLLanguageRecognizer()
        r.processString(text)
        if let raw = r.dominantLanguage?.rawValue {
            if raw.hasPrefix("es") { return "es" }
            if raw.hasPrefix("en") { return "en" }
        }
    }
    let lower = text.lowercased()
    // Quick heuristics for Spanish if NL fails
    if lower.range(of: "[áéíóúñ¿¡]", options: .regularExpression) != nil { return "es" }
    if lower.contains(" el ") || lower.contains(" la ") || lower.contains(" de ") || lower.hasPrefix("¿") { return "es" }
    return "en"
}

/// Choose a high-quality voice for English or Spanish with regional preferences.
private func bestVoiceForENorES(_ lang: String) -> AVSpeechSynthesisVoice? {
    let prefs: [String] = (lang == "es")
        ? ["es-US", "es-MX", "es-ES", "es-419"]
        : ["en-US", "en-GB", "en-AU", "en-IN"]
    for code in prefs {
        if let v = AVSpeechSynthesisVoice(language: code) { return v }
    }
    // Fallback to any voice sharing the language prefix.
    return AVSpeechSynthesisVoice.speechVoices().first { $0.language.hasPrefix(lang) }
}


