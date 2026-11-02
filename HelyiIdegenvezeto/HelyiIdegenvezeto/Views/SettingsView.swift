import CoreLocation
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var guide: TourGuide
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("sk-ant-…", text: $guide.apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Claude API-kulcs")
                } footer: {
                    Text("Kulcsot a platform.claude.com oldalon kérhetsz. A Kulcskarikában tároljuk.")
                }

                Section("Keresési sugár: \(guide.radius) m") {
                    Slider(value: Binding(
                        get: { Double(guide.radius) },
                        set: { guide.radius = Int($0) }
                    ), in: 200...3000, step: 100)
                    Text("Sétához 200–500 m, autózáshoz 1000–3000 m ajánlott.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Ismertető részletessége") {
                    Picker("Alaposság", selection: $guide.effort) {
                        Text("Gyors").tag("low")
                        Text("Közepes").tag("medium")
                        Text("Alapos").tag("high")
                    }
                    .pickerStyle(.segmented)
                }

                Section("Beszédtempó") {
                    Slider(value: $guide.speechRate, in: 0.35...0.6)
                }

                Section("Helymeghatározás") {
                    LabeledContent("Engedély", value: authorizationText)
                    if guide.location.authorization != .authorizedAlways {
                        Button("Beállítások megnyitása") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        Text("A háttérben futáshoz válaszd a „Mindig” lehetőséget.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button("Elmondott helyek törlése", role: .destructive) { confirmReset = true }
                } footer: {
                    Text("Ezután a már hallott helyekről is újra mesélni fogok.")
                }
            }
            .navigationTitle("Beállítások")
            .toolbar { Button("Kész") { dismiss() } }
            .confirmationDialog("Biztosan törlöd?", isPresented: $confirmReset) {
                Button("Törlés", role: .destructive) { guide.resetHistory() }
            }
        }
    }

    private var authorizationText: String {
        switch guide.location.authorization {
        case .authorizedAlways: return "Mindig"
        case .authorizedWhenInUse: return "Használat közben"
        case .denied, .restricted: return "Tiltva"
        default: return "Nincs megadva"
        }
    }
}
