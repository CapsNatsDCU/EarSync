//
//  VisualTranslationView.swift
//  EarSync
//
//  Created by Josiah Lenowitz on 11/3/25.
//

import SwiftUI
import PhotosUI
import VisionKit
import AVFoundation
import Vision
import UIKit

struct VisualTranslationView: View {
    // UI state
    @State private var previewImage: UIImage?
    @State private var recognizedSourceText: String = ""
    @State private var translatedText: String = ""
    @State private var showCameraPicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isTranslating = false

    // Language selection with search (default to Spanish)
    @State private var search = ""
    @State private var target: VTLanguageItem = VTLanguageCatalog.common.first { $0.bcp47 == "es" }!

    private var filteredLanguages: [VTLanguageItem] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return VTLanguageCatalog.common }
        return VTLanguageCatalog.common.filter {
            $0.name.lowercased().contains(q) || $0.bcp47.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 12) {

            // Top bar: Auto source + target picker + camera/library
            HStack(spacing: 10) {
                Label("Auto", systemImage: "bolt.badge.clock")
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))

                Image(systemName: "arrow.left.arrow.right")

                Menu {
                    Section {
                        TextField("Search", text: $search)
                    }
                    ForEach(filteredLanguages) { lang in
                        Button {
                            target = lang
                        } label: {
                            HStack {
                                Text(lang.name)
                                Spacer()
                                if lang == target { Image(systemName: "checkmark") }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(target.name)
                        Image(systemName: "chevron.down")
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
                }

                Spacer(minLength: 8)

                // Take photo (camera)
                Button {
                    showCameraPicker = true
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(10)
                        .background(Circle().fill(Color(.secondarySystemBackground)))
                }

                // Pick photo (library)
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(10)
                        .background(Circle().fill(Color(.secondarySystemBackground)))
                }
            }
            .font(.subheadline)

            // Live DataScanner overlay (like Google camera translate)
            if #available(iOS 16.0, *),
               DataScannerViewController.isSupported,
               DataScannerViewController.isAvailable {
                Text("Live camera text (overlay)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VTScannerView(
                    recognizesMultiple: true,
                    isScanning: .constant(true)
                ) { _ in
                    // No-op to avoid spamming main text; wire custom behavior if you want.
                }
                .frame(minHeight: 220)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Preview of last still image you captured or chose
            if let img = previewImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Recognized source text
            VStack(alignment: .leading, spacing: 6) {
                Text("Detected text")
                    .font(.headline)
                ScrollView {
                    Text(recognizedSourceText.isEmpty ? "—" : recognizedSourceText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 80, maxHeight: 140)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
            }

            // Translation
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Translation")
                        .font(.headline)
                    if isTranslating { ProgressView().scaleEffect(0.8) }
                    Spacer()
                    Button {
                        speekText(text: translatedText)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                    }
                    .disabled(translatedText.isEmpty)
                }

                ScrollView {
                    Text(translatedText.isEmpty ? "—" : translatedText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 80, maxHeight: 160)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
            }

            Spacer()
        }
        .padding()
        // Camera sheet
        .sheet(isPresented: $showCameraPicker) {
            CameraCaptureView { img in
                showCameraPicker = false
                Task { await process(image: img) }
            }
        }
        // Library change handler
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await process(image: image)
                }
            }
        }
    }

    // MARK: - Pipeline

    private func process(image: UIImage) async {
        previewImage = image
        recognizedSourceText = await VTOCR.recognizeText(from: image)
        guard !recognizedSourceText.isEmpty else {
            translatedText = ""
            return
        }
        isTranslating = true
        defer { isTranslating = false }
        if #available(iOS 16, *) {
            translatedText = await translateText(recognizedSourceText, to: target.bcp47)
        } else {
            translatedText = recognizedSourceText
        }
    }
}

// MARK: - Simple camera capture

struct CameraCaptureView: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let c = UIImagePickerController()
        c.sourceType = .camera
        c.delegate = context.coordinator
        c.allowsEditing = false
        return c
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coord { Coord(onImage: onImage) }

    final class Coord: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage) -> Void
        init(onImage: @escaping (UIImage) -> Void) { self.onImage = onImage }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let img = info[.originalImage] as? UIImage { onImage(img) }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Live VisionKit Scanner (overlay like Google)

@available(iOS 16.0, *)
struct VTScannerView: UIViewControllerRepresentable {
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
        init(onRecognized: @escaping ([String]) -> Void) { self.onRecognized = onRecognized }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            onRecognized(addedItems.compactMap(Self.describe))
        }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didUpdate updatedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            onRecognized(updatedItems.compactMap(Self.describe))
        }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didRemove removedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) { }

        static func describe(_ item: RecognizedItem) -> String? {
            if case .text(let t) = item { return t.transcript }
            return nil
        }
    }
}

// MARK: - Language catalog for target selection (scoped to this file)

fileprivate struct VTLanguageItem: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let bcp47: String
}

fileprivate enum VTLanguageCatalog {
    static let common: [VTLanguageItem] = [
        .init(name: "Spanish", bcp47: "es"),
        .init(name: "English", bcp47: "en"),
        .init(name: "French", bcp47: "fr"),
        .init(name: "German", bcp47: "de"),
        .init(name: "Italian", bcp47: "it"),
        .init(name: "Portuguese", bcp47: "pt"),
        .init(name: "Japanese", bcp47: "ja"),
        .init(name: "Korean", bcp47: "ko"),
        .init(name: "Chinese (Simplified)", bcp47: "zh-Hans"),
        .init(name: "Chinese (Traditional)", bcp47: "zh-Hant")
    ]
}

// MARK: - OCR for still images (scoped to this file)

fileprivate enum VTOCR {
    static func recognizeText(from image: UIImage) async -> String {
        guard let cg = image.cgImage else { return "" }

        return await withCheckedContinuation { cont in
            // Perform Vision work on a background queue and create Vision objects inside the block
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest { request, _ in
                    let strings: [String] = (request.results as? [VNRecognizedTextObservation])?
                        .compactMap { $0.topCandidates(1).first?.string } ?? []
                    cont.resume(returning: strings.joined(separator: "\n"))
                }
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true

                let handler = VNImageRequestHandler(cgImage: cg, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    cont.resume(returning: "")
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        VisualTranslationView()
            .navigationTitle("Camera translate")
            .navigationBarTitleDisplayMode(.inline)
    }
}
