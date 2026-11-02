import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var guide: TourGuide
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(guide.status, systemImage: guide.isRunning ? "dot.radiowaves.left.and.right" : "pause.circle")
                            .font(.headline)
                            .foregroundStyle(guide.isRunning ? .green : .secondary)

                        if let place = guide.currentPlace {
                            Text(place.title).font(.title2.bold())
                            Text(guide.currentText)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Indítsd el az idegenvezetést, és nyugodtan válts át a navigációra – "
                                 + "a közeli látnivalókról a háttérben is mesélni fogok.")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    ControlsView(speech: guide.speech)
                }

                if !guide.history.isEmpty {
                    Section("Elmondott helyek") {
                        ForEach(guide.history) { item in
                            DisclosureGroup {
                                Text(item.text).font(.callout)
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(item.place.title)
                                    Text(item.date, style: .time)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Idegenvezető")
            .toolbar {
                Button { showSettings = true } label: { Image(systemName: "gearshape") }
            }
            .sheet(isPresented: $showSettings) { SettingsView().environmentObject(guide) }
            .alert("Hiba", isPresented: Binding(
                get: { guide.errorMessage != nil },
                set: { if !$0 { guide.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(guide.errorMessage ?? "")
            }
            .onAppear { guide.location.requestPermission() }
        }
    }
}

/// Indítás / leállítás / átugrás gombok. Külön nézet, hogy a felolvasás állapotát is figyelje.
private struct ControlsView: View {
    @EnvironmentObject private var guide: TourGuide
    @ObservedObject var speech: SpeechService

    var body: some View {
        HStack {
            Button {
                guide.isRunning ? guide.stop() : guide.start()
            } label: {
                Label(guide.isRunning ? "Leállítás" : "Indítás",
                      systemImage: guide.isRunning ? "stop.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(guide.isRunning ? .red : .accentColor)

            if speech.isSpeaking {
                Button {
                    guide.skip()
                } label: {
                    Label("Következő", systemImage: "forward.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .controlSize(.large)
    }
}
