//
//  VisualTranslationView.swift
//  EarSync
//
//  Created by Josiah Lenowitz on 11/3/25.
//

import SwiftUI
import VisionKit
import AVFoundation

struct VisualTranslationView: View {
    @Environment(\.openURL) private var openURL
    @State private var isAuthorized = false
    @State private var items: [String] = []
    @State private var isScanning = false
    @State private var recognizesMultiple = true
    
    var body: some View {
        VStack(spacing: 12) {
            // Permission request UI shown when camera access not yet granted
            if !isAuthorized {
                VStack(spacing: 8) {
                    Text("Camera access required")
                        .font(.headline)
                    Text("Please grant permission to access the camera.")
                    Button("Request Permission") {
                        AVCaptureDevice.requestAccess(for: .video) { granted in
                            DispatchQueue.main.async { isAuthorized = granted }
                        }
                    }
                }
                .padding()
            } else if !DataScannerViewController.isSupported {
                // Message shown when Data Scanner feature is not supported on the device
                Text("Data Scanner not supported on this device.")
            } else if !DataScannerViewController.isAvailable {
                // Message shown when Data Scanner is unavailable (e.g., camera busy or restricted)
                Text("Data Scanner unavailable. Ensure camera is free and not restricted.")
            } else {
                // Toggle for switching between single and multiple recognition
                Toggle("Recognize multiple items", isOn: $recognizesMultiple)
                    .padding(.horizontal)

                // Scanner view displaying live camera feed and recognized text
                ScannerView(
                    recognizesMultiple: recognizesMultiple,
                    isScanning: $isScanning,
                    onRecognized: { newValues in
                        // Combine new and existing items, remove duplicates in order, keep newest 50
                        let combined = newValues + items
                        var seen = Set<String>()
                        let unique = combined.filter { seen.insert($0).inserted }
                        items = Array(unique.prefix(50))
                    }
                )
                .id("\(recognizesMultiple)")
                .overlay(alignment: .topTrailing) {
                    Button(isScanning ? "Pause" : "Scan") {
                        isScanning.toggle()
                    }
                    .padding(8)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .padding()
                }
                .frame(minHeight: 320)
                
                // Tappable list rows: tapping a row executes an action based on the item string
                List {
                    ForEach(items, id: \.self) { item in
                        Text(item)
                            .lineLimit(3)
                            .contentShape(Rectangle()) // make full row tappable
                            .onTapGesture {
                                executeAction(for: item)
                            }
                    }
                }
            }
        }
        // Camera permission check on appear
        .task {
            // Check existing permission
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            isAuthorized = (status == .authorized)
        }
    }
    
    private func executeAction(for item: String) {
        // Simple router: if it's a URL, open it. Otherwise speak the text.
        if let url = URL(string: item.trimmingCharacters(in: .whitespacesAndNewlines)),
           ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
            openURL(url)
            return
        }
        let utterance = AVSpeechUtterance(string: item)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        let synth = AVSpeechSynthesizer()
        synth.speak(utterance)
    }
}

struct ScannerView: UIViewControllerRepresentable {
    let recognizesMultiple: Bool
    @Binding var isScanning: Bool
    let onRecognized: ([String]) -> Void
    
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.text(languages: [])],
            qualityLevel: .balanced,
            recognizesMultipleItems: recognizesMultiple,
            isHighFrameRateTrackingEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        Task { @MainActor in
            if isScanning {
                try? uiViewController.startScanning()
            } else {
                uiViewController.stopScanning()
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onRecognized: onRecognized)
    }
    
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onRecognized: ([String]) -> Void
        
        init(onRecognized: @escaping ([String]) -> Void) {
            self.onRecognized = onRecognized
        }
        
        // Called when new text is recognized
        func dataScanner(_ dataScanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            onRecognized(addedItems.compactMap(Self.describe))
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController,
                         didUpdate updatedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            // Optional: handle updates. Here we just surface latest strings.
            onRecognized(updatedItems.compactMap(Self.describe))
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController,
                         didRemove removedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            // No-op
        }
        
        static func describe(_ item: RecognizedItem) -> String? {
            if case .text(let t) = item {
                return t.transcript
            }
            return nil
        }
    }
}

#Preview {
    HomeTabView()
}
