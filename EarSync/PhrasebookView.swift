//
//  PhrasebookView.swift
//  EarSync
//
//  Created by Josiah Lenowitz on 10/29/25.
//

import SwiftUI
import SwiftData

struct PhrasebookView: View {
    @Bindable var p: Phrasebook
    @State private var selectedPhrase: Phrase? = nil
    var body: some View {
        VStack(alignment: .leading) {
            Text("Phrasebook")
                .font(.headline)
            ScrollView{
                ForEach(p.phrases, id: \.phraseID) { phrase in
                    VStack(alignment: .leading) {
                        Text(phrase.usrLanText)
                            .font(.body)
                        if !phrase.transText.isEmpty {
                            Text(phrase.transText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Divider()
                    }
                    .onTapGesture {
                        selectedPhrase = phrase
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .sheet(item: $selectedPhrase) { phr in
            singlePhraseView(p: phr, pb: p)
        }
        .task {
            if p.phrases.isEmpty {
                await p.addPhrase(Phrase(text: "I would like to buy a hamburger"))
                await p.addPhrase(Phrase(text: "I would like to buy a beer"))
                await p.addPhrase(Phrase(text: "Is this a gay?"))
                await p.addPhrase(Phrase(text: "¿Este es un bar?"))
            }
        }
    }
}

struct singlePhraseView: View {
    @Environment(\.dismiss) private var dismiss
    var p: Phrase
    var pb: Phrasebook
    
    var body: some View {
        VStack{
            Text(p.usrLanText)
                .font(.system(size: 45))
                .minimumScaleFactor(0.01)

            Spacer()

            Text(p.transText)
                .font(.system(size: 100))
                .minimumScaleFactor(0.1)
            
            Spacer()
            
            ZStack{
                Rectangle()
                    .background(.colorModeMatch)
                HStack{
                    Button(action: {
                        speekText(text: p.transText)
                    }, label: {
                        Image(systemName: "speaker.wave.3")
                            .font(.system(size: 75))
                            .foregroundStyle(.white)
                            .contentTransition(.symbolEffect(.replace))
                            .padding(.trailing)
                    })
                    Divider()
                    Button(action: {
                        //delete phrase from phrasebook
                    }, label: {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 75))
                            .foregroundStyle(.red)
                            .contentTransition(.symbolEffect(.replace))
                            .padding(.trailing)
                    })
                }
            }
            .cornerRadius(20)
            .frame(maxHeight: 125)
                
        }
        .padding()
        .background(Color.accentColor)
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(false)
        .overlay(alignment: .topLeading) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .padding(12)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding()
        }
    }
    
}

