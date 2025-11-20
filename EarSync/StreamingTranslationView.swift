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

/// A minimal view that captures live microphone input, continuously transcribes it,
/// and translates the partial transcript as it is updated.
/// The recognized and translated text are displayed in the UI.
@available(iOS 16.0, *)
struct StreamingTranslationView: View {
    @State private var isRecording = false
    @State private var recognizedText: String = ""
    @State private var translatedText: String = ""

    // Shared input language for STT (English / Spanish, etc.)
    @AppStorage("inputLanguage") private var inputLanguage: String = "en-US"
    
    // Speech recognition support
    private let audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer? {
        SFSpeechRecognizer(locale: Locale(identifier: inputLanguage))
    }
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Input language", selection: $inputLanguage) {
                Text("English").tag("en-US")
                Text("Spanish").tag("es-ES")
            }
            .pickerStyle(.segmented)
            Text("Live Translator")
                .font(.title2.bold())
            
            Group {
                Text("Recognized:")
                    .font(.headline)
                Text(recognizedText.isEmpty ? "–" : recognizedText)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
            }
            
            Group {
                Text("Translation:")
                    .font(.headline)
                Text(translatedText.isEmpty ? "–" : translatedText)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
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
                let partial = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.recognizedText = partial
                }
                // Translate asynchronously on partial updates
                Task {
                    if #available(iOS 26, *) {
                        let translation = await callToAIAsync(text: partial)
                        await MainActor.run {
                            self.translatedText = translation
                        }
                    } else {
                        // Fallback: mirror the transcript if translation API isn’t available
                        await MainActor.run {
                            self.translatedText = partial
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
    
    /// Stop streaming audio and reset the recognizer.
    private func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
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
