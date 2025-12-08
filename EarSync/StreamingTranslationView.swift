//
//  StreamingTranslationView.swift
//  EarSync
//
//  Created by Josiah Lenowitz on 11/20/25.
//

import SwiftUI
import AVFoundation
import Speech
import Translation
import SwiftData

/// A minimal view that captures live microphone input, continuously transcribes it,
/// and translates the partial transcript as it is updated.
/// The recognized and translated text are displayed in the UI.
@available(iOS 16.0, *)
struct StreamingTranslationView: View {
    @Environment(\.modelContext) private var modelContext
    /// Minimum number of new words before we translate another chunk (unless the result is final).
    private let minChunkSize: Int = 6
    /// Minimum time between AI refinement calls, in seconds.
    private let refineInterval: TimeInterval = 2.0
    /// Maximum number of characters to show in the "Recognized" box.
    /// Older text is kept in state but not displayed once this limit is exceeded.
    private let maxRecognizedCharacters: Int = 400

    @State private var isRecording: Bool = false
    @State private var recognizedText: String = ""
    @State private var translatedText: String = ""
    /// Number of words in `recognizedText` that have already been translated.
    @State private var lastWordCountTranslated: Int = 0
    /// Context for AI-assisted refinement of the current sentence.
    @State private var sentenceContext = SentenceContext(
        previousSource: nil,
        previousTarget: nil,
        currentSource: "",
        currentTarget: nil
    )
    /// Whether an AI refinement call is currently in flight.
    @State private var isRefining: Bool = false
    /// The last time we invoked AI refinement, used to rate-limit calls.
    @State private var lastRefineDate: Date? = nil
    /// Whether we have already produced a final, full-utterance translation for
    /// the current recording session. Used to ignore stale chunk completions
    /// that might arrive after the final translation.
    @State private var hasFinalTranslation: Bool = false

    /// A truncated view of `recognizedText` that keeps only the most recent content
    /// when the full text would overflow the UI. This does not affect the stored
    /// transcription, only what is drawn on screen.
    private var recognizedDisplayText: String {
        guard recognizedText.count > maxRecognizedCharacters else {
            return recognizedText
        }
        // Keep only the last N characters and prepend an ellipsis to indicate there is more.
        let suffix = recognizedText.suffix(maxRecognizedCharacters)
        return "… " + String(suffix)
    }

    // Shared input/output language codes across the app
    @AppStorage("inputLanguageCode") private var inputLanguageCode: String = "en-US"
    @AppStorage("outputLanguageCode") private var outputLanguageCode: String = "es-ES"
    
    // Speech recognition support
    private let audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer? {
        SFSpeechRecognizer(locale: Locale(identifier: inputLanguageCode))
    }
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Input language", selection: $inputLanguageCode) {
                Text("English").tag("en-US")
                Text("Spanish").tag("es-ES")
            }
            .pickerStyle(.segmented)
            Text("Live Translator")
                .font(.title2.bold())
            
            Group {
                Text("Recognized:")
                    .font(.headline)
                Text(recognizedText.isEmpty ? "–" : recognizedDisplayText)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
            }
            
            Group {
                Text("Translation:")
                    .font(.headline)
                if isRefining {
                    Text("Refining…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(translatedText.isEmpty ? "–" : translatedText)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
//                Toggle("Speak each sentence", isOn: $speakSentencesWhileStreaming)
//                    .font(.caption)
//                    .toggleStyle(.switch)
//                    .padding(.top, 2)
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Button(action: toggleRecording) {
                    Image(systemName: isRecording ? "mic.fill" : "mic")
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                        .padding()
                        .background(isRecording ? Color.red : Color.blue)
                        .clipShape(Circle())
                }
                Spacer()
            }
            .padding(.bottom)
        }
        .padding()
        .onAppear {
            requestPermissions()
        }
        .onChange(of: inputLanguageCode) { newValue in
            if newValue.hasPrefix("en") {
                outputLanguageCode = "es-ES"
            } else if newValue.hasPrefix("es") {
                outputLanguageCode = "en-US"
            }
        }
    }
    
    private func toggleRecording() {
        isRecording.toggle()
        if isRecording {
            startRecording()
        } else {
            stopRecording()
        }
    }
    
    /// Request permission for microphone and speech recognition.
    private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { status in
            if status != .authorized {
                print("Speech recognition not authorized: \(status)")
            }
        }
        
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                if !granted {
                    print("Microphone permission denied")
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                if !granted {
                    print("Microphone permission denied")
                }
            }
        }
    }
    
    /// Start streaming audio to the speech recognizer.
    private func startRecording() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("Recognizer unavailable")
            isRecording = false
            return
        }
        
        // Reset state for a fresh streaming session
        recognizedText = ""
        translatedText = ""
        lastWordCountTranslated = 0
        sentenceContext = SentenceContext(
            previousSource: nil,
            previousTarget: nil,
            currentSource: "",
            currentTarget: nil
        )
        isRefining = false
        lastRefineDate = nil
        hasFinalTranslation = false
        
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord,
                                    mode: .measurement,
                                    options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to configure session: \(error)")
            isRecording = false
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true
        
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest!) { result, error in
            if let result = result {
                let fullText = result.bestTranscription.formattedString
                let isFinal = result.isFinal

                DispatchQueue.main.async {
                    // Always show the full evolving transcript.
                    self.recognizedText = fullText

                    // Split the recognized text into words.
                    let words = fullText
                        .components(separatedBy: .whitespacesAndNewlines)
                        .filter { !$0.isEmpty }

                    // Ensure our word index is in range.
                    if self.lastWordCountTranslated < 0 {
                        self.lastWordCountTranslated = 0
                    }
                    if self.lastWordCountTranslated > words.count {
                        self.lastWordCountTranslated = words.count
                    }

                    let newWordCount = words.count
                    let remainingWords = newWordCount - self.lastWordCountTranslated

                    // If there are not enough new words yet and the result is not final, wait for more.
                    guard remainingWords > 0 else { return }
                    if remainingWords < self.minChunkSize && !isFinal {
                        return
                    }

                    // Build the chunk to translate from the yet-untranslated words.
                    let newWords = words[self.lastWordCountTranslated..<newWordCount]
                    let chunkToTranslate = newWords.joined(separator: " ")

                    // Mark all current words as translated.
                    self.lastWordCountTranslated = newWordCount

                    Task {
                        // Ensure we don't translate Spanish -> Spanish or English -> English by accident.
                        let target: String
                        if inputLanguageCode.hasPrefix("es") && outputLanguageCode.hasPrefix("es") {
                            // User is speaking Spanish; translate to English.
                            target = "en-US"
                        } else if inputLanguageCode.hasPrefix("en") && outputLanguageCode.hasPrefix("en") {
                            // User is speaking English; translate to Spanish.
                            target = "es-ES"
                        } else {
                            target = outputLanguageCode
                        }

                        // If this is the final recognition result, do a simple full-text translation
                        // of the entire transcript and REPLACE the current output. We skip any
                        // chunk-based logic here to avoid duplication and complex final refinement.
                        if isFinal {
                            let fullSource = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !fullSource.isEmpty else { return }

                            // One-shot translation of the full utterance.
                            let fullTranslation = await translateText(fullSource, to: target)
                            let trimmedFull = fullTranslation.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmedFull.isEmpty else { return }

                            await MainActor.run {
                                // 🔥 Replace the entire translatedText with the final full translation.
                                self.translatedText = trimmedFull
                                self.hasFinalTranslation = true

                                // Keep context in sync with the final text.
                                self.sentenceContext.previousSource = fullSource
                                self.sentenceContext.previousTarget = trimmedFull
                                self.sentenceContext.currentSource = ""
                                self.sentenceContext.currentTarget = nil

                                // Save this completed utterance into chat history.
                                // Each finished recording becomes its own Item in the history list.
                                let newItem = Item(timestamp: Date())
                                let part = ConversationPart(originalText: fullSource, translatedText: trimmedFull)
                                newItem.conversation.append(part)
                                self.modelContext.insert(newItem)
                            }

                            return
                        }

                        // --- Non-final path: chunk-based translation + optional AI refinement ---

                        // 1. Base, on-device translation for this chunk.
                        let baseTranslation = await translateText(chunkToTranslate, to: target)

                        // Decide whether to invoke AI refinement for this chunk (mid-stream), rate-limited.
                        let shouldRefineChunk: Bool = await MainActor.run {
                            if let lastTime = self.lastRefineDate {
                                return Date().timeIntervalSince(lastTime) >= self.refineInterval
                            } else {
                                return true
                            }
                        }

                        // 2. Optionally refine just this chunk with AI, using prior context.
                        var finalChunk = baseTranslation
                        if shouldRefineChunk {
                            // Mark refinement as in progress and record the time.
                            await MainActor.run {
                                self.isRefining = true
                                self.lastRefineDate = Date()
                            }

                            // Build a context where the current sentence is just this chunk.
                            let ctxForAI: SentenceContext = await MainActor.run {
                                SentenceContext(
                                    previousSource: self.sentenceContext.previousSource,
                                    previousTarget: self.sentenceContext.previousTarget,
                                    currentSource: chunkToTranslate,
                                    currentTarget: baseTranslation
                                )
                            }

                            let refinedChunk = await refineCurrentSentence(ctx: ctxForAI, targetLang: target)
                            let trimmedRefined = refinedChunk.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmedRefined.isEmpty {
                                finalChunk = trimmedRefined
                            }

                            await MainActor.run {
                                self.isRefining = false
                            }
                        }

                        // 3. Append the (possibly refined) chunk and update running context.
                        await MainActor.run {
                            // If we already have a final translation for this session,
                            // ignore any late-arriving chunk completions.
                            guard !self.hasFinalTranslation else { return }
                            let trimmed = finalChunk.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }

                            // Append to the visible translated text.
                            if self.translatedText.isEmpty {
                                self.translatedText = trimmed
                            } else {
                                if self.translatedText.hasSuffix(" ") || trimmed.hasPrefix(" ") {
                                    self.translatedText += trimmed
                                } else {
                                    self.translatedText += " " + trimmed
                                }
                            }

                            // Update previous context by concatenating this chunk.
                            let newPrevSource: String
                            if let prevSrc = self.sentenceContext.previousSource, !prevSrc.isEmpty {
                                newPrevSource = prevSrc + " " + chunkToTranslate
                            } else {
                                newPrevSource = chunkToTranslate
                            }

                            let newPrevTarget: String
                            if let prevTgt = self.sentenceContext.previousTarget, !prevTgt.isEmpty {
                                newPrevTarget = prevTgt + " " + trimmed
                            } else {
                                newPrevTarget = trimmed
                            }

                            self.sentenceContext.previousSource = newPrevSource
                            self.sentenceContext.previousTarget = newPrevTarget
                            self.sentenceContext.currentSource = ""
                            self.sentenceContext.currentTarget = nil
                        }
                    }
                }
            }
            if error != nil {
                stopRecording()
            }
        }
        
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
            isRecording = false
        }
    }

    /// Wrapper around the app's existing text-to-speech function.
    /// If your TTS helper has a different name or signature, adjust this body.
    private func speakTranslatedSentence(_ text: String) {
        // Assuming you already have something like `speakText(_:)` defined.
        speakText(text: text)
    }

    /// Stop streaming audio and signal the recognition request,
    /// but allow the recognition task to finish so we receive the final result.
    private func stopRecording() {
        // Stop capturing audio and signal the recognition request that no more
        // audio will arrive, but allow the recognition task to finish so we
        // receive the final result (and translate the last few words).
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        isRecording = false

        do {
            try AVAudioSession.sharedInstance().setActive(false,
                                                          options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate session: \(error)")
        }
    }
}

#if DEBUG
@available(iOS 16.0, *)
struct StreamingTranslationView_Previews: PreviewProvider {
    static var previews: some View {
        StreamingTranslationView()
    }
}
#endif
