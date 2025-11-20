//
//  PhrasebookView.swift
//  EarSync
//
//  Created by Josiah Lenowitz on 10/29/25.
//

import SwiftUI
import SwiftData
import AVFoundation

struct PhrasebookView: View {
    @Bindable var p: Phrasebook
    @State private var selectedPhrase: Phrase? = nil
    @State private var selectedCategory: (name: String, phrases: [(en: String, es: String)])? = nil

    // built-in Spanish categories for tourist mode
    private let builtinCategories: [(name: String, phrases: [(en: String, es: String)])] = [
        (
            name: "Restaurant",
            phrases: [
                ("Mesa para dos, por favor.", "Table for two, please."),
                ("La cuenta, por favor.", "The bill, please."),
                ("Agua, por favor.", "Water, please."),
                ("¿Tiene menú en inglés?", "Do you have a menu in English?"),
                ("¿Pica?", "Is it spicy?"),
                ("Un café con leche, por favor.", "Coffee with milk, please."),
                ("Cerveza", "Beer"),
                ("Hielo", "Ice"),
                ("Tenedor", "Fork"),
                ("Servilleta", "Napkin")
            ]
        ),
        (
            name: "Transportation",
            phrases: [
                ("¿Dónde está el metro?", "Where is the metro?"),
                ("¿Dónde está la parada de autobús?", "Where is the bus stop?"),
                ("Necesito un taxi.", "I need a taxi."),
                ("¿Cuánto cuesta el billete?", "How much is the ticket?"),
                ("¿Cuál es esta parada?", "Which stop is this?"),
                ("Aeropuerto", "Airport"),
                ("Estación de tren", "Train station")
            ]
        ),
        (
            name: "Grocery / Shopping",
            phrases: [
                ("¿Cuánto cuesta esto?", "How much is this?"),
                ("¿Dónde está el supermercado?", "Where is the supermarket?"),
                ("Solo estoy mirando.", "I am just looking."),
                ("¿Acepta tarjeta?", "Do you accept cards?"),
                ("Bolsa", "Bag"),
                ("Leche", "Milk"),
                ("Pan", "Bread"),
                ("Queso", "Cheese")
            ]
        ),
        (
            name: "About me",
            phrases: [
                ("Soy de Estados Unidos.", "I am from the United States."),
                ("No hablo español muy bien.", "I don’t speak Spanish very well."),
                ("¿Puede repetirlo?", "Can you repeat that?"),
                ("Me llamo…", "My name is …"),
                ("Estoy viajando por vacaciones.", "I’m traveling for vacation.")
            ]
        )
    ]
    
    private let ttsSynth = AVSpeechSynthesizer()

    private func speakSpanish(_ text: String) {
        let session = AVAudioSession.sharedInstance()
        do {
            // plain playback is safer when other parts of the app might have been recording
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to configure audio session for TTS: \(error)")
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "es-ES") // Spanish
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        ttsSynth.speak(utterance)
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Phrasebook")
                .font(.headline)
            
            if selectedCategory != nil {
                Button {
                    selectedCategory = nil
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                .padding(.bottom, 4)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    if let cat = selectedCategory {
                        // INSIDE A CATEGORY: show the phrases, roomy
                        Text(cat.name)
                            .font(.title2.bold())

                        ForEach(Array(cat.phrases.enumerated()), id: \.offset) { _, phr in
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(phr.es)    // Spanish first
                                        .font(.headline)
                                    Text(phr.en)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                // speaker button on the right
                                Button {
                                    speakSpanish(phr.es)
                                } label: {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.title3)
                                        .foregroundColor(.accentColor)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
                            .onTapGesture {
                                // still allow opening the full-screen phrase view
                                Task {
                                    let temp = await Phrase(text: phr.es)
                                    temp.transText = phr.en
                                    await MainActor.run {
                                        selectedPhrase = temp
                                    }
                                }
                            }
                        }

                        // a spacer so you can scroll
                        Spacer(minLength: 20)

                    } else {
                        // TOP LEVEL: show the sections as big buttons
                        ForEach(Array(builtinCategories.enumerated()), id: \.offset) { _, cat in
                            Button {
                                selectedCategory = cat
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(cat.name)
                                            .font(.headline)
                                        Text("Tap to see phrases for \(cat.name.lowercased())")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
                            }
                            .buttonStyle(.plain)
                        }

                        // user / stored phrases from SwiftData
                        if !p.phrases.isEmpty {
                            Text("Your saved phrases")
                                .font(.headline)
                                .padding(.top, 4)

                            ForEach(p.phrases, id: \.phraseID) { phrase in
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading) {
                                        Text(phrase.usrLanText)
                                            .font(.body)
                                        if !phrase.transText.isEmpty {
                                            Text(phrase.transText)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Button {
                                        // might want Spanish here too, but the saved ones are user-language → translated, so:
                                        speakSpanish(phrase.transText.isEmpty ? phrase.usrLanText : phrase.transText)
                                    } label: {
                                        Image(systemName: "speaker.wave.2.fill")
                                            .font(.title3)
                                            .foregroundColor(.accentColor)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 4)
                                .onTapGesture {
                                    selectedPhrase = phrase
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .sheet(item: $selectedPhrase) { phr in
            singlePhraseView(p: phr)
        }
        .task {
            // leave empty for now, user-added phrases will show here
        }
    }
}

struct singlePhraseView: View {
    @Environment(\.dismiss) private var dismiss
    var p: Phrase
    
    var body: some View {
        GeometryReader {geo in
            ZStack {
                Color.accentColor
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    // Top controls
                    HStack {
                        Button {
                            speekText(text: p.transText)
                        } label: {
                            Image(systemName: "speaker.wave.3.fill")
                                .font(.system(size: 48, weight: .semibold))
                        }
                        
                        Spacer()
                        
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 48, weight: .semibold))
                        }
                    }
                    .padding(.top, 25)
                    .padding(.horizontal, 12)
                    .foregroundStyle(.colorModeOpposite)
                    
                    Spacer()
                    
                    // Poster card
                    VStack(spacing: 16) {
                        Text(p.usrLanText)
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.6)
                            .foregroundColor(.colorModeOpposite.opacity(0.9))
                            .frame(maxHeight: geo.size.height * 0.15)
                        
                        if p.transText.count > 80 {
                            ScrollView {
                                Text(p.transText)
                                    .font(.system(size: 36, weight: .bold))
                                    .minimumScaleFactor(0.15)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(nil)
                                    .foregroundColor(.colorModeOpposite)
                            }

                        } else {
                            Text(p.transText)
                                .font(.system(size: 80, weight: .bold))
                                .minimumScaleFactor(0.15)
                                .multilineTextAlignment(.center)
                                .lineLimit(nil)
                                .foregroundColor(.colorModeOpposite)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(.colorModeMatch)
                    )
                    .padding(.horizontal, 16)
                    .shadow(radius: 10, y: 4)
                    
                    Spacer()
                }
            }
            .foregroundStyle(.colorModeMatch)
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled(false)
        }
    }
    
}

#Preview {
    singlePhraseView(p: Phrase(usrLanText: "I want to eat something delicious and amazing with an alcoholic beverage, then I want to have an amazing fuck",
                               transText: "Quiero comer algo delicioso y espectacular con una bebida alcohólica, y luego quiero tener un polvo increíble."))
}
#Preview {
    let pb = Phrasebook()

    pb.phrases.append(
        Phrase(usrLanText: "Where is the bathroom?", transText: "¿Dónde está el baño?")
    )
    pb.phrases.append(
        Phrase(usrLanText: "Do you speak English?", transText: "¿Habla inglés?")
    )
    pb.phrases.append(
        Phrase(usrLanText: "I need help.", transText: "Necesito ayuda.")
    )

    return PhrasebookView(p: pb)
}
