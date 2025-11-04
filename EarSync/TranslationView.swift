import SwiftUI
import Translation
import Speech
import SwiftData
import AVFoundation

struct TranslationView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: Item
    @State private var text = ""
    @State private var isRecording = false
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var configuration: TranslationSession.Configuration?
    @State private var availableLanguages = [Locale.Language]()
    private let languageAvailability = LanguageAvailability()
    
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer()
    
    @MainActor
    private func loadSupportedLanguages() async {
        availableLanguages = await languageAvailability.supportedLanguages
    }
    
    var body: some View {
        ScrollView {
            ForEach(item.conversation, id: \ConversationPart.persistentModelID) { part in
                ZStack{
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(Color.accentColor))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary, lineWidth: 1))
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
                                do {
                                    modelContext.insert(part)
                                    try modelContext.save()
                                } catch {
                                    print("[debug] failed to save converstion part: \(error)")
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
                            Button(action: {
                                speekText(text: part.translatedText)
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
            // 📝 Text Input Box with Buttons Inside
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6)) // Light background
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary, lineWidth: 1))
                
                HStack {
                    // 🎤 Microphone Button (Left)
                    Button(action: {
                        isRecording.toggle()
                        if isRecording {
                            Task { startRecording() }
                        } else {
                            Task { await stopRecording() }
                        }
                    }) {
                        Image(systemName: isRecording ? "mic.fill" : "mic")
                            .foregroundStyle(.white)
                            .font(.title3)
                            .padding(10)
                            .background(isRecording ? Color.red : Color.blue)
                            .clipShape(Circle())
                            .shadow(radius: 3)
                    }
                    
                    // 📝 Text Input Area
                    TextEditor(text: $text)
                        .frame(height: 100) // Adjust height
                        .background(Color.clear) // Make transparent
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 5)
                        .scrollContentBackground(.hidden)
                    
                    // 🌍 Translate Button (Right)
                    Button(action: {
                        let input = text

                        // Ensure this item is attached to the current ModelContext before mutating relationships
                        modelContext.insert(item)

                            Task {
                                await item.appendPart(input)
                                await MainActor.run { self.text = "" }
                            }
                        
                    }) {
                        Image(systemName: "arrow.forward.circle.fill")
                            .foregroundStyle(.colorModeOpposite)//make this depend on light/dark mode
                            .font(.title3)
                            .padding(10)
                            .background(Color.accentColor)
                            .clipShape(Circle())
                            .shadow(radius: 3)
                    }
                }
                .padding(.horizontal, 8) // Spacing inside the box
            }
            .frame(height: 120) // Make the entire text box larger

        }
        .onAppear {
            requestSpeechPermission()
        }
        .padding(.horizontal, 25)
        .defaultScrollAnchor(.bottom)
    }
    
    // ✅ Request speech permission
    private func requestSpeechPermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            if status != .authorized {
                print("Speech recognition permission denied!")
            }
        }
    }
    
    // ✅ Start recording voice
    @MainActor private func startRecording() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else { return }
        
        // Configure audio session for recording + playback so TTS can still route to speaker
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("[audio] Failed to configure AVAudioSession: \(error)")
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        
        let inputNode = audioEngine.inputNode
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                DispatchQueue.main.async {
                    self.text = result.bestTranscription.formattedString
                }
            }
            if error != nil {
                Task { await stopRecording() }
            }
        }
        
        let format = inputNode.inputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: format) { buffer, _ in
            // Guard against empty buffers which trigger: mDataByteSize (0) should be non-zero
            if buffer.frameLength > 0 {
                recognitionRequest.append(buffer)
            }
        }
        
        audioEngine.prepare()
        try? audioEngine.start()
    }
    
    // ✅ Stop recording voice
    @MainActor private func stopRecording() async {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        self.recognitionRequest?.endAudio()
        self.recognitionTask?.cancel()
        self.recognitionRequest = nil
        self.recognitionTask = nil
        
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("[audio] Failed to deactivate AVAudioSession: \(error)")
        }
    }
}

#Preview {
    do {
        let container = try ModelContainer(for: Item.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let item = Item(timestamp: Date())
        container.mainContext.insert(item)

        // Add sample conversation entry
        Task {
            await item.appendPart("I would like to buy a hamburger")
        }

        return TranslationView(item: item)
            .modelContainer(container)
    } catch {
        return Text("Preview failed: \(String(describing: error))")
    }
}

