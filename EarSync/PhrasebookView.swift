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
                ("Table for two, please.", "Mesa para dos, por favor."),
                ("The bill, please.", "La cuenta, por favor."),
                ("Water, please.", "Agua, por favor."),
                ("Do you have a menu in English?", "¿Tiene menú en inglés?"),
                ("Is it spicy?", "¿Pica?"),
                ("Coffee with milk, please.", "Un café con leche, por favor."),
                ("Beer", "Cerveza"),
                ("Ice", "Hielo"),
                ("Fork", "Tenedor"),
                ("Napkin", "Servilleta")
            ]
        ),
        (
            name: "Transportation",
            phrases: [
                ("Where is the metro?", "¿Dónde está el metro?"),
                ("Where is the bus stop?", "¿Dónde está la parada de autobús?"),
                ("I need a taxi.", "Necesito un taxi."),
                ("How much is the ticket?", "¿Cuánto cuesta el billete?"),
                ("Which stop is this?", "¿Cuál es esta parada?"),
                ("Airport", "Aeropuerto"),
                ("Train station", "Estación de tren")
            ]
        ),
        (
            name: "Grocery / Shopping",
            phrases: [
                ("How much is this?", "¿Cuánto cuesta esto?"),
                ("Where is the supermarket?", "¿Dónde está el supermercado?"),
                ("I am just looking.", "Solo estoy mirando."),
                ("Do you accept cards?", "¿Acepta tarjeta?"),
                ("Bag", "Bolsa"),
                ("Milk", "Leche"),
                ("Bread", "Pan"),
                ("Cheese", "Queso")
            ]
        ),
        (
            name: "About me",
            phrases: [
                ("I am from the United States.", "Soy de Estados Unidos."),
                ("I don’t speak Spanish very well.", "No hablo español muy bien."),
                ("Can you repeat that?", "¿Puede repetirlo?"),
                ("My name is …", "Me llamo…"),
                ("I’m traveling for vacation.", "Estoy viajando por vacaciones.")
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
        VStack{
            ZStack{
                Rectangle()
                    .background(.colorModeMatch)
                HStack{
                    Spacer()
                    Button(action: {
                        speekText(text: p.transText)
                    }, label: {
                        Image(systemName: "speaker.wave.3")
                            .font(.system(size: 75))
                            .foregroundStyle(.colorModeOpposite)
                            .contentTransition(.symbolEffect(.replace))
                            .padding(.trailing)
                    })
                    
                    Spacer()
                    
                    Button(action: {
                        dismiss()
                    }, label: {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 75))
                            .foregroundStyle(.colorModeOpposite)
                            .contentTransition(.symbolEffect(.replace))
                            .padding(.trailing)
                    })
                    Spacer()
                }
            }
            .frame(maxHeight: 125)

            
            Spacer()
            
            HStack{
                Spacer()
                Text(p.usrLanText)
                    .font(.system(size: 45))
                    .minimumScaleFactor(0.1)
                    .padding(20)
                    .foregroundStyle(Color.gray)
                    .frame(alignment: .trailing)
                    .multilineTextAlignment(TextAlignment.trailing)
            }
            
            Spacer()
            
            Text(p.transText)
                .font(.system(size: 1000))
                .minimumScaleFactor(0.01)
                .padding(20)
                .foregroundStyle(.black)
            
            
            

        }
        .background(Color.accentColor)
        .foregroundStyle(.colorModeMatch)
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(false)
    }
    
}

#Preview {
    singlePhraseView(p: Phrase(usrLanText: "I want to eat", transText: "Yo querio comer"))
}
