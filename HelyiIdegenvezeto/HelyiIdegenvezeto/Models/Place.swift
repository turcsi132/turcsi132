import CoreLocation
import Foundation

/// Egy közeli, Wikipédián szereplő hely (látnivaló, épület, emlékmű, stb.).
struct Place: Identifiable, Hashable {
    /// Egyedi azonosító: "nyelv:pageid", pl. "hu:12345".
    var id: String { "\(language):\(pageID)" }

    let pageID: Int
    let language: String
    let title: String
    let coordinate: CLLocationCoordinate2D
    /// Távolság méterben a keresés pillanatában.
    var distance: CLLocationDistance

    static func == (lhs: Place, rhs: Place) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Egy már elmondott ismertető (az előzmények listájához).
struct Narration: Identifiable, Hashable {
    let id = UUID()
    let place: Place
    let text: String
    let date: Date
}
