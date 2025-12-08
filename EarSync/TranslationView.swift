import SwiftUI
import Translation
import Speech
import SwiftData
import AVFoundation

struct TranslationView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var phrasebooks: [Phrasebook]
    @Bindable var item: Item

    @State private var text = ""
    @State private var isRecording = false

    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var configuration: TranslationSession.Configuration?
    @State private var availableLanguages = [Locale.Language]()
    
    let copyText: String = ""
    @State private var copied = false

    @AppStorage("currentScenarioMode") private var currentScenarioMode: String = ScenarioMode.tourist.rawValue
    // Shared input/output language codes across the app
    @AppStorage("inputLanguageCode") private var inputLanguageCode: String = "en-US"
    @AppStorage("outputLanguageCode") private var outputLanguageCode: String = "es-ES"

    private let languageAvailability = LanguageAvailability()

    // Audio / speech properties
    private let audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer? {
        SFSpeechRecognizer(locale: Locale(identifier: inputLanguageCode))
    }

    @MainActor
    private func loadSupportedLanguages() async {
        availableLanguages = await languageAvailability.supportedLanguages
    }

    var body: some View {
        ScrollView {
            // Show current scenario mode chosen on Home
            if let mode = ScenarioMode(rawValue: currentScenarioMode) {
                HStack {
                    Text("Mode: \(mode.title)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.bottom, 8)
            }

            // Input language toggle shared with StreamingTranslationView
            Picker("Input language", selection: $inputLanguageCode) {
                Text("English").tag("en-US")
                Text("Spanish").tag("es-ES")
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 8)

            // Show all conversation parts for this item
            ForEach(item.conversation, id: \ConversationPart.persistentModelID) { part in
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(Color.accentColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.secondary, lineWidth: 1)
                        )
                    VStack {
                        HStack {
                            Text(part.originalText)
                                .font(.body)
                                .padding(.leading)
                                .foregroundColor(.black)
                            Spacer()
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    part.isSaved.toggle()
                                }

                                // Get or create the shared phrasebook
                                let pb = defaultPhrasebook(in: modelContext)

                                if part.isSaved {
                                    // Add this conversation line as a phrase
                                    let phrase = Phrase(c: part)
                                    pb.addPhrase(phrase)
                                } else {
                                    // Optional: remove from phrasebook when un-starring
                                    if let index = pb.phrases.firstIndex(where: {
                                        $0.usrLanText == part.originalText &&
                                        $0.transText == part.translatedText
                                    }) {
                                        pb.phrases.remove(at: index)
                                    }
                                }

                                do {
                                    try modelContext.save()
                                } catch {
                                    print("[debug] failed to save phrasebook: \(error)")
                                }
                            }) {
                                Image(systemName: part.isSaved ? "star.slash.fill" : "star")
                                    .font(.title)
                                    .foregroundStyle(.black)
                                    .contentTransition(.symbolEffect(.replace))
                                    .symbolEffect(.bounce, value: part.isSaved)
                                    .animation(.easeInOut(duration: 0.2), value: part.isSaved)
                                    .padding(.trailing)
                            }
                        }
                        Divider()
                        HStack {
                            Spacer()
                            Text(part.translatedText)
                                .font(.body)
                                .padding(.leading)
                                .foregroundColor(.black)
                                .onLongPressGesture {
                                                UIPasteboard.general.string = copyText
                                                copied = true
                                            }
                                            .overlay(alignment: .topTrailing) {
                                                if copied {
                                                    Text("Copied")
                                                        .font(.caption2)
                                                        .padding(4)
                                                }
                                            }
                            Button(action: {
                                speakText(text: part.translatedText)
                            }, label: {
                                Image(systemName: "speaker.wave.3")
                                    .font(.title)
                                    .foregroundStyle(.black)
                                    .contentTransition(.symbolEffect(.replace))
                                    .animation(.easeInOut(duration: 0.2), value: part.isSaved)
                                    .padding(.trailing)
                            })
                        }
                    }
                    .padding(.vertical)
                }
            }

            // Input area with microphone and send button
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary, lineWidth: 1)
                    )

                HStack {
                    // Microphone button
                    Button(action: {
                        #if targetEnvironment(simulator)
                        // On the simulator, the input audio device is often missing and causes long delays.
                        print("[audio] Microphone capture is disabled on simulator.")
                        isRecording = false
                        return
                        #else
                        isRecording.toggle()
                        if isRecording {
                            Task { startRecording() }
                        } else {
                            Task { await stopRecording() }
                        }
                        #endif
                    }) {
                        Image(systemName: isRecording ? "mic.fill" : "mic")
                            .foregroundStyle(.white)
                            .font(.title3)
                            .padding(10)
                            .background(isRecording ? Color.red : Color.blue)
                            .clipShape(Circle())
                            .shadow(radius: 3)
                    }

                    // Text input
                    TextEditor(text: $text)
                        .frame(height: 100)
                        .background(Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 5)
                        .scrollContentBackground(.hidden)

                    // Translate/send button
                    Button(action: {
                        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !input.isEmpty else { return }

                        // Ensure this item is attached to the current ModelContext before mutating relationships
                        modelContext.insert(item)

                        // Note: actual translation logic is in simpleTranslate(...) in NetworkCalls.swift.
                        // If that function returns the same text, add a fallback there.
                        Task {
                            await item.appendPart(input)
                            await MainActor.run { self.text = "" }
                        }
                    }) {
                        Image(systemName: "arrow.forward.circle.fill")
                            .foregroundStyle(.colorModeOpposite)
                            .font(.title3)
                            .padding(10)
                            .background(Color.accentColor)
                            .clipShape(Circle())
                            .shadow(radius: 3)
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(height: 120)
        }
        .onAppear {
            requestSpeechPermission()
        }
        .onChange(of: inputLanguageCode) { oldValue, newValue in
            if newValue.hasPrefix("en") {
                outputLanguageCode = "es-ES"
            } else if newValue.hasPrefix("es") {
                outputLanguageCode = "en-US"
            }
        }
        .padding(.horizontal, 25)
        .defaultScrollAnchor(.bottom)
    }

    // Helper to fetch or create the default phrasebook
    private func defaultPhrasebook(in context: ModelContext) -> Phrasebook {
        if let existing = phrasebooks.first {
            return existing
        } else {
            let pb = Phrasebook()
            context.insert(pb)
            return pb
        }
    }

    // MARK: - Speech Permission

    private func requestSpeechPermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            if status != .authorized {
                print("Speech recognition permission denied")
            }
        }
    }

    // MARK: - Recording

    /// Starts speech recording and streaming to Apple's speech recognizer.
    /// On simulator this is disabled because of missing audio devices.
    @MainActor private func startRecording() {
        #if targetEnvironment(simulator)
        print("[audio] startRecording called on simulator; skipping.")
        isRecording = false
        return
        #else

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("[audio] Speech recognizer not available")
            isRecording = false
            return
        }

        // Configure audio session for recording and playback
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord,
                                    mode: .measurement,
                                    options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("[audio] Failed to configure AVAudioSession: \(error)")
            isRecording = false
            return
        }

        // Create request
        let request = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest = request
        request.shouldReportPartialResults = true

        // Start recognition task
        recognitionTask = recognizer.recognitionTask(with: request) { result, error in
            if let result = result {
                DispatchQueue.main.async {
                    self.text = result.bestTranscription.formattedString
                }
            }
            if error != nil {
                Task { await self.stopRecording() }
            }
        }

        let inputNode = audioEngine.inputNode

        // Get the current format from the input node
        let nodeFormat = inputNode.outputFormat(forBus: 0)

        // If the device reports 0 Hz or 0 channels, bail out to avoid a crash
        if nodeFormat.sampleRate == 0 || nodeFormat.channelCount == 0 {
            print("[audio] Input format invalid, skipping installTap")
            isRecording = false
            return
        }

        // Remove any tap that might already be there
        inputNode.removeTap(onBus: 0)

        // Let AVAudioEngine choose the right format
        inputNode.installTap(onBus: 0,
                             bufferSize: 2048,
                             format: nil) { buffer, _ in
            if buffer.frameLength > 0 {
                self.recognitionRequest?.append(buffer)
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("[audio] Failed to start audio engine: \(error)")
            isRecording = false
        }
        #endif
    }

    /// Stops recording and tears down the audio engine and recognition task.
    @MainActor private func stopRecording() async {
        #if !targetEnvironment(simulator)
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        #endif

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("[audio] Failed to deactivate AVAudioSession: \(error)")
        }

        isRecording = false
    }
}
