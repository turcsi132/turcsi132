import Foundation

/// A Claude API (Messages API) hívása nyers HTTP-n keresztül – Swifthez nincs hivatalos SDK.
struct ClaudeService {
    enum ClaudeError: LocalizedError {
        case missingAPIKey
        case http(Int, String)
        case refusal
        case emptyResponse

        var errorDescription: String? {
            switch self {
            case .missingAPIKey: return "Nincs megadva Claude API-kulcs (Beállítások)."
            case .http(let code, let body): return "Claude API hiba (\(code)): \(body)"
            case .refusal: return "A modell nem válaszolt erre a kérésre."
            case .emptyResponse: return "Üres válasz érkezett."
            }
        }
    }

    /// Ha a modell szerint a hely nem érdemes ismertetésre, ezt a szót adja vissza.
    static let skipToken = "KIHAGY"

    var apiKey: String
    var model = "claude-opus-5-5"
    /// "low" = gyors válasz (vezetés közben ez a fontos); "medium"/"high" = alaposabb.
    var effort = "low"

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    private static let systemPrompt = """
    Te egy lelkes, tájékozott magyar idegenvezető vagy. Az utazó éppen autózik, kerékpározik \
    vagy sétál, és a telefonja hangosan felolvassa, amit írsz – miközben a háttérben akár \
    egy navigációs alkalmazás is fut.

    Feladatod: a megadott helyről élvezetes, szóban elmondható ismertetőt írni magyarul.
    - Mondd el, mi ez a hely, mikor épült vagy jött létre, ki építtette/tervezte, és milyen \
    érdekes történelmi események, történetek, legendák kapcsolódnak hozzá (mi történt ott, mikor).
    - Kizárólag a megadott forrásszövegben szereplő tényekre támaszkodj. Ha egy évszám vagy \
    adat nincs benne, ne találd ki.
    - A szöveget felolvassák: ne használj markdownt, felsorolást, címsort, emojit, zárójeles \
    megjegyzést vagy URL-t. Rövid, gördülékeny, élőbeszédszerű mondatokat írj.
    - Az évszámokat számmal írd (például: 1896-ban). Rövidítéseket írd ki.
    - Kezdd úgy, hogy az utazó tudja, melyik helyről van szó, és ha meg van adva, merre található.
    - Terjedelem: körülbelül 120–200 szó.
    - Ha a hely nem igazi látnivaló és nincs róla érdekes mondanivaló (például egy átlagos utca, \
    buszmegálló, cég, iroda, közigazgatási egység száraz adatokkal), akkor csak ennyit válaszolj: \
    \(skipToken)
    """

    /// Visszaadja a felolvasandó ismertetőt, vagy `nil`-t, ha a hely nem érdemes rá.
    func narration(placeTitle: String,
                   distanceMeters: Int,
                   direction: String?,
                   sourceLanguage: String,
                   sourceText: String) async throws -> String? {
        guard !apiKey.isEmpty else { throw ClaudeError.missingAPIKey }

        var userText = "Hely: \(placeTitle)\nTávolság: kb. \(distanceMeters) méter"
        if let direction { userText += "\nIrány az utazótól: \(direction)" }
        userText += "\n\nForrás (\(sourceLanguage) Wikipédia):\n\(sourceText)"

        let body: [String: Any] = [
            "model": model,
            // A Claude Opus 5.5 mindig gondolkodik is, ezért kell tartalék a kimenetre.
            "max_tokens": 4000,
            "output_config": ["effort": effort],
            // Ha a biztonsági szűrő elutasítana, a szerver automatikusan másik modellel próbálja.
            "fallbacks": "default",
            "system": Self.systemPrompt,
            "messages": [["role": "user", "content": userText]],
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            throw ClaudeError.http(status, String(data: data, encoding: .utf8) ?? "")
        }

        let message = try JSONDecoder().decode(MessageResponse.self, from: data)
        if message.stop_reason == "refusal" { throw ClaudeError.refusal }

        // Csak a "text" blokkokat olvassuk fel (a "thinking" blokkokat kihagyjuk).
        let text = message.content
            .filter { $0.type == "text" }
            .compactMap(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else { throw ClaudeError.emptyResponse }
        if text.uppercased().hasPrefix(Self.skipToken) { return nil }
        return text
    }
}

private struct MessageResponse: Decodable {
    struct Block: Decodable {
        let type: String
        let text: String?
    }
    let content: [Block]
    let stop_reason: String?
}
