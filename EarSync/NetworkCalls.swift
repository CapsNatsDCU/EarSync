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
import FoundationModels

private let sharedSynth = AVSpeechSynthesizer()

private var inputLang: String {
    UserDefaults.standard.string(forKey: "inputLanguageCode") ?? "en-US"
}

private var outputLang: String {
    UserDefaults.standard.string(forKey: "outputLanguageCode") ?? "es-ES"
}

/// New async API — does the work off the main actor and returns a result you can `await`.
@available(iOS 26, *)
func simpleTranslate(text: String) async -> String {
    let demoMode = UserDefaults.standard.bool(forKey: "demoMode")
    print(text)
    let targetLang = outputLang
    print("[debug] translating from \(inputLang) to \(targetLang)")
    do {
        let installedSource = Locale.Language(identifier: inputLang)
        let target = Locale.Language(identifier: outputLang)
        let session = TranslationSession(installedSource: installedSource, target: target)
        let result = try await session.translate(text).targetText
        print("result ", result)
        return result
    } catch {
        return text
    }
}

/// Backwards-compatible wrapper so existing code that calls `callToAIAsync` keeps working.
/// Internally just forwards to `simpleTranslate(text:)`.
@available(iOS 26, *)
func callToAIAsync(text: String) async -> String {
    await simpleTranslate(text: text)
}

@available(iOS 26, *)
func callToAINew(c: ConversationPart) async {
    let demoMode = UserDefaults.standard.bool(forKey: "demoMode")
    let sourceLang = inputLang
    let targetLang = outputLang

    print("[debug] callToAINew translating from \(sourceLang) to \(targetLang)")
    print("[debug] original:", c.originalText)

    if demoMode {
        // Demo mode: use on-device Translation framework, same as simpleTranslate
        do {
            let installedSource = Locale.Language(identifier: sourceLang)
            let target = Locale.Language(identifier: targetLang)
            let session = TranslationSession(installedSource: installedSource, target: target)
            let result = try await session.translate(c.originalText).targetText
            c.translatedText = result
        } catch {
            print("[demo translate] error:", error)
            // Fall back to leaving the existing translation alone
        }
    } else {
        // Full AI path: send the whole ConversationPart context to the LLM
        let session = LanguageModelSession()

        var contextLines: [String] = []
        contextLines.append("ORIGINAL TEXT: \"\(c.originalText)\"")

        let trimmedExisting = c.translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedExisting.isEmpty {
            contextLines.append("EXISTING TRANSLATION (may be imperfect): \"\(trimmedExisting)\"")
        }

        if let setting = c.setting, !setting.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            contextLines.append("SETTING / SITUATION: \(setting)")
        }

        if let locDesc = c.locationDescription, !locDesc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            contextLines.append("LOCATION DESCRIPTION: \(locDesc)")
        } else if let lat = c.latitude, let lon = c.longitude {
            contextLines.append("APPROXIMATE COORDINATES: \(lat), \(lon)")
        }

        let contextBlock = contextLines.joined(separator: "\n")

        let prompt = """
        You are helping interpret a live conversation in real time.

        Use the context below to understand what the speaker likely means and then provide the best possible translation.

        \(contextBlock)

        TASK:
        - Translate the ORIGINAL TEXT from \(sourceLang) to \(targetLang).
        - Use the setting and location to pick natural, context-appropriate phrasing.
        - If the existing translation is already good, you may reuse it, but improve it if needed.
        - Preserve the tone and level of politeness.

        Return ONLY the final translation in \(targetLang), with no explanations, labels, or quotes.
        """

        do {
            let response = try await session.respond(to: prompt)
            let candidate = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

            if !candidate.isEmpty {
                c.translatedText = candidate
                print("[AI] updated translation:", candidate)
            } else {
                print("[AI] empty response, keeping previous translation")
            }
        } catch {
            print("[AI] callToAINew error:", error)
            // Keep the previous translation if something goes wrong
        }
    }
}

@available(iOS 26, *)
private func AIpass(text: String) async -> String {
    let session = LanguageModelSession()

    do {
        // This returns LanguageModelSession.Response<String>
        let response = try await session.respond(to: "Translate this text from \(inputLang) to \(outputLang). Return only the translated text. Input: \(text)")
        // Get the plain text from the response
        let newText = response.content

        return newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? text : newText
    } catch {
        print("[AI] error: \(error)")
        return text
    }
}

/// Legacy sync API — kept for compatibility; prefer `simpleTranslate`.
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

func speakText(text: String) {
    // Speak the provided text using AVSpeechSynthesizer
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

    // Decide which language to speak in: prefer global outputLang when it is English or Spanish,
    // otherwise fall back to detecting from the text.
    let ol = outputLang
    let baseLang: String
    if ol.hasPrefix("es") {
        baseLang = "es"
    } else if ol.hasPrefix("en") {
        baseLang = "en"
    } else {
        baseLang = detectENorES(from: trimmed)
    }

    let utterance = AVSpeechUtterance(string: trimmed)

    if let preferredVoice = bestVoiceForENorES(baseLang) {
        utterance.voice = preferredVoice
    } else {
        // Fallback to using outputLang directly if no preferred EN/ES voice is found
        utterance.voice = AVSpeechSynthesisVoice(language: ol)
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

// MARK: - Target-forced translation helper

@available(iOS 16, *)
func translateText(_ text: String, to targetBCP47: String) async -> String {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "" }

    // If caller passed an explicit target language, use it; otherwise default to the global output language
    let resolvedTarget = targetBCP47.isEmpty ? outputLang : targetBCP47

    // For streaming and other quick translations, we always use the on-device
    // Translation framework here so we get stable, literal translations and
    // avoid LLM hallucinations.
    guard #available(iOS 26, *) else {
        print("[translateText] TranslationSession not available on this OS, returning original text")
        return trimmed
    }

    print("[translateText] input=\"\(trimmed)\"")
    print("[translateText] source=\(inputLang) target=\(resolvedTarget)")

    do {
        let source = Locale.Language(identifier: inputLang)
        let target = Locale.Language(identifier: resolvedTarget)
        let session = TranslationSession(installedSource: source, target: target)
        let translated = try await session.translate(trimmed).targetText
        let result = translated.trimmingCharacters(in: .whitespacesAndNewlines)

        print("[translateText] result=\"\(result)\"")
        return result.isEmpty ? trimmed : result
    } catch {
        print("[translateText] error during translation: \(error)")
        return trimmed
    }
}

@available(iOS 16, *)
func refineCurrentSentence(ctx: SentenceContext,
                           targetLang: String) async -> String {
    let previousSource = ctx.previousSource ?? ""
    let previousTarget = ctx.previousTarget ?? ""
    let currentSource  = ctx.currentSource
    let currentTarget  = ctx.currentTarget ?? ""

    let prompt = """
    You are a translation assistant.
    Source language text comes from real-time speech, so it may be messy.
    Your job is to produce a natural-sounding translation in \(targetLang).

    PREVIOUS SENTENCE (source):
    \(previousSource.isEmpty ? "(none)" : previousSource)

    PREVIOUS SENTENCE (translation):
    \(previousTarget.isEmpty ? "(none)" : previousTarget)

    CURRENT SENTENCE (source, possibly partial):
    \(currentSource)

    CURRENT SENTENCE (existing translation, if any):
    \(currentTarget.isEmpty ? "(none yet)" : currentTarget)

    TASK:
    - Return an improved translation for the CURRENT SENTENCE only.
    - Make it natural but faithful.
    - Try to stay consistent with the previous sentence’s translation.
    - Return only the translation text, nothing else.
    """

    // Use your existing LLM call here (e.g. AIpass or a variant)
    let result = await AIpass(text: prompt)
    return result.trimmingCharacters(in: .whitespacesAndNewlines)
}
