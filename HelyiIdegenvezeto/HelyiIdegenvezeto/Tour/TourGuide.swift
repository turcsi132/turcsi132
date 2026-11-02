import CoreLocation
import Foundation

/// Az alkalmazás "agya": helyzet → közeli helyek → AI-ismertető → felolvasás.
@MainActor
final class TourGuide: ObservableObject {
    // MARK: Állapot a felületnek
    @Published private(set) var isRunning = false
    @Published private(set) var status = "Indításra kész"
    @Published private(set) var currentPlace: Place?
    @Published private(set) var currentText = ""
    @Published private(set) var history: [Narration] = []
    @Published var errorMessage: String?

    // MARK: Beállítások (UserDefaults)
    @Published var radius: Int { didSet { defaults.set(radius, forKey: Keys.radius) } }
    @Published var effort: String { didSet { defaults.set(effort, forKey: Keys.effort) } }
    @Published var speechRate: Float {
        didSet { defaults.set(speechRate, forKey: Keys.rate); speech.rate = speechRate }
    }
    @Published var apiKey: String { didSet { KeychainStore.save(apiKey, for: Keys.apiKey) } }

    let location = LocationService()
    let speech = SpeechService()
    private let wikipedia = WikipediaService()

    private let defaults = UserDefaults.standard
    private var narratedIDs: Set<String>
    private var candidates: [Place] = []
    private var lastSearch: (location: CLLocation, date: Date)?
    private var cycleTask: Task<Void, Never>?

    private enum Keys {
        static let radius = "radius", effort = "effort", rate = "speechRate"
        static let narrated = "narratedIDs", apiKey = "anthropicAPIKey"
    }

    init() {
        radius = defaults.object(forKey: Keys.radius) as? Int ?? 600
        effort = defaults.string(forKey: Keys.effort) ?? "low"
        speechRate = defaults.object(forKey: Keys.rate) as? Float ?? 0.5
        apiKey = KeychainStore.load(Keys.apiKey)
        narratedIDs = Set(defaults.stringArray(forKey: Keys.narrated) ?? [])
        speech.rate = speechRate

        location.onLocation = { [weak self] loc in self?.handle(loc) }
    }

    // MARK: Vezérlés

    func start() {
        guard !apiKey.isEmpty else {
            errorMessage = "Add meg a Claude API-kulcsot a Beállításokban."
            return
        }
        isRunning = true
        status = "Helyzet meghatározása…"
        location.start()
        if let loc = location.lastLocation { handle(loc) }
    }

    func stop() {
        isRunning = false
        cycleTask?.cancel() // a futó ciklus magától lezárul és nullázza magát
        speech.stop()
        location.stop()
        status = "Leállítva"
    }

    /// Az aktuális ismertető átugrása – utána jön a következő hely.
    func skip() {
        speech.stop()
    }

    func resetHistory() {
        narratedIDs.removeAll()
        defaults.removeObject(forKey: Keys.narrated)
        history.removeAll()
        candidates.removeAll()
        lastSearch = nil
    }

    // MARK: Fő ciklus

    private func handle(_ loc: CLLocation) {
        guard isRunning, cycleTask == nil else { return }
        cycleTask = Task { [weak self] in
            await self?.runCycle(from: loc)
            self?.cycleTask = nil
        }
    }

    private func runCycle(from initial: CLLocation) async {
        var loc = initial
        // Addig mesélünk egymás után, amíg van új, közeli hely.
        while isRunning, !Task.isCancelled {
            let narrated = await narrateNextPlace(near: loc)
            guard narrated, let latest = location.lastLocation else { break }
            loc = latest
        }
        if isRunning, !Task.isCancelled {
            status = "Figyelem a környéket…"
        }
    }

    /// Igazzal tér vissza, ha elmondott egy ismertetőt.
    private func narrateNextPlace(near loc: CLLocation) async -> Bool {
        do {
            try await refreshCandidatesIfNeeded(around: loc)

            // Legfeljebb 4 jelöltet próbálunk (a "nem érdekes" helyeket a modell kihagyja).
            for _ in 0..<4 {
                guard isRunning, !Task.isCancelled else { return false }
                guard let place = bestCandidate(from: loc) else { return false }
                markNarrated(place)

                status = "Utánanézek: \(place.title)"
                let source = try await wikipedia.extract(for: place)
                guard source.count > 150 else { continue }

                status = "Ismertető készül: \(place.title)"
                let claude = ClaudeService(apiKey: apiKey, effort: effort)
                let current = location.lastLocation ?? loc
                let distance = Int(current.distance(from: CLLocation(latitude: place.coordinate.latitude,
                                                                    longitude: place.coordinate.longitude)))
                guard let text = try await claude.narration(
                    placeTitle: place.title,
                    distanceMeters: distance,
                    direction: Self.direction(from: current, to: place.coordinate),
                    sourceLanguage: place.language == "hu" ? "magyar" : "angol",
                    sourceText: source
                ) else { continue }

                guard isRunning, !Task.isCancelled else { return false }
                currentPlace = place
                currentText = text
                history.insert(Narration(place: place, text: text, date: Date()), at: 0)
                status = "Mesélek: \(place.title)"
                await speech.speak(text)
                return true
            }
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
                status = "Hiba – újrapróbálom a következő helyzetnél"
            }
        }
        return false
    }

    // MARK: Helyek kiválasztása

    private func refreshCandidatesIfNeeded(around loc: CLLocation) async throws {
        if let last = lastSearch,
           loc.distance(from: last.location) < 250,
           Date().timeIntervalSince(last.date) < 120 {
            return
        }
        status = "Közeli látnivalók keresése…"
        let searchRadius = max(radius * 2, 1000)
        var places = try await wikipedia.nearbyPlaces(around: loc.coordinate, radius: searchRadius, language: "hu")
        if places.isEmpty {
            // Külföldön a magyar Wikipédia gyakran üres – ilyenkor az angolt használjuk.
            places = try await wikipedia.nearbyPlaces(around: loc.coordinate, radius: searchRadius, language: "en")
        }
        candidates = places
        lastSearch = (loc, Date())
    }

    private func bestCandidate(from loc: CLLocation) -> Place? {
        let scored: [(Place, Double)] = candidates.compactMap { place in
            guard !narratedIDs.contains(place.id) else { return nil }
            let target = CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
            let distance = loc.distance(from: target)
            guard distance <= Double(radius) else { return nil }

            var score = distance
            // Haladás közben az előttünk lévő helyek előnyt kapnak, a mögöttünk lévők hátrányt.
            if let relative = Self.relativeBearing(from: loc, to: place.coordinate) {
                if abs(relative) > 110 { score *= 3 } else if abs(relative) < 45 { score *= 0.7 }
            }
            var updated = place
            updated.distance = distance
            return (updated, score)
        }
        return scored.min { $0.1 < $1.1 }?.0
    }

    private func markNarrated(_ place: Place) {
        narratedIDs.insert(place.id)
        defaults.set(Array(narratedIDs), forKey: Keys.narrated)
    }

    // MARK: Irányszámítás

    private static func bearing(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let lat1 = a.latitude * .pi / 180, lat2 = b.latitude * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    /// A hely iránya a haladási irányhoz képest (-180…180), ha éppen mozgunk.
    private static func relativeBearing(from loc: CLLocation, to target: CLLocationCoordinate2D) -> Double? {
        guard loc.course >= 0, loc.speed > 1.5 else { return nil }
        var relative = bearing(from: loc.coordinate, to: target) - loc.course
        if relative > 180 { relative -= 360 }
        if relative < -180 { relative += 360 }
        return relative
    }

    static func direction(from loc: CLLocation, to target: CLLocationCoordinate2D) -> String {
        if let rel = relativeBearing(from: loc, to: target) {
            let names = ["előtted", "előtted jobbra", "jobbra", "mögötted jobbra",
                         "mögötted", "mögötted balra", "balra", "előtted balra"]
            let normalized = (rel + 360).truncatingRemainder(dividingBy: 360)
            return names[Int((normalized + 22.5) / 45) % 8]
        }
        let names = ["északra", "északkeletre", "keletre", "délkeletre",
                     "délre", "délnyugatra", "nyugatra", "északnyugatra"]
        return names[Int((bearing(from: loc.coordinate, to: target) + 22.5) / 45) % 8]
    }
}
