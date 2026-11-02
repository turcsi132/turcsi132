import CoreLocation
import Foundation

/// Közeli helyek és azok leírásának lekérése a Wikipédiából (ingyenes, kulcs nélküli API).
/// A leírás adja a tényszerű alapot (építési évek, események), amiből az AI mesél –
/// így sokkal kisebb az esélye, hogy kitalált évszámokat mondjon.
struct WikipediaService {
    enum WikiError: Error { case badResponse }

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        // A Wikimedia API-szabályzat kéri az azonosító User-Agentet.
        config.httpAdditionalHeaders = ["User-Agent": "HelyiIdegenvezeto/0.1 (iOS; github.com/turcsi132)"]
        return URLSession(configuration: config)
    }()

    /// Helyek a megadott sugárban (max. 10 000 m), távolság szerint növekvő sorrendben.
    func nearbyPlaces(around coordinate: CLLocationCoordinate2D,
                      radius: Int,
                      language: String,
                      limit: Int = 30) async throws -> [Place] {
        var components = URLComponents(string: "https://\(language).wikipedia.org/w/api.php")!
        components.queryItems = [
            .init(name: "action", value: "query"),
            .init(name: "list", value: "geosearch"),
            .init(name: "gscoord", value: "\(coordinate.latitude)|\(coordinate.longitude)"),
            .init(name: "gsradius", value: String(min(max(radius, 10), 10_000))),
            .init(name: "gslimit", value: String(limit)),
            .init(name: "format", value: "json"),
            .init(name: "formatversion", value: "2"),
        ]
        let response: GeoSearchResponse = try await get(components.url!)
        return response.query?.geosearch.map {
            Place(pageID: $0.pageid,
                  language: language,
                  title: $0.title,
                  coordinate: CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon),
                  distance: $0.dist)
        } ?? []
    }

    /// A cikk teljes szövege egyszerű szövegként (a tokenköltség miatt levágva).
    func extract(for place: Place, maxCharacters: Int = 9_000) async throws -> String {
        var components = URLComponents(string: "https://\(place.language).wikipedia.org/w/api.php")!
        components.queryItems = [
            .init(name: "action", value: "query"),
            .init(name: "prop", value: "extracts"),
            .init(name: "explaintext", value: "1"),
            .init(name: "exsectionformat", value: "plain"),
            .init(name: "pageids", value: String(place.pageID)),
            .init(name: "format", value: "json"),
            .init(name: "formatversion", value: "2"),
        ]
        let response: ExtractResponse = try await get(components.url!)
        let text = response.query?.pages.first?.extract ?? ""
        return String(text.prefix(maxCharacters))
    }

    private func get<T: Decodable>(_ url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw WikiError.badResponse }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - API válaszok

private struct GeoSearchResponse: Decodable {
    struct Query: Decodable { let geosearch: [Item] }
    struct Item: Decodable {
        let pageid: Int
        let title: String
        let lat: Double
        let lon: Double
        let dist: Double
    }
    let query: Query?
}

private struct ExtractResponse: Decodable {
    struct Query: Decodable { let pages: [Page] }
    struct Page: Decodable {
        let pageid: Int?
        let title: String?
        let extract: String?
    }
    let query: Query?
}
