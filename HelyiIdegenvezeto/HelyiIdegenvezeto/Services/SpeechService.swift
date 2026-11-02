import AVFoundation

/// Magyar nyelvű felolvasás. A navigáció hangját és a zenét lehalkítja (duck), nem állítja le,
/// és a felolvasás végén visszaadja a hangerőt a többi alkalmazásnak.
@MainActor
final class SpeechService: NSObject, ObservableObject {
    @Published private(set) var isSpeaking = false

    var rate: Float = AVSpeechUtteranceDefaultSpeechRate

    private let synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Felolvassa a szöveget, és csak akkor tér vissza, ha végzett (vagy megszakították).
    func speak(_ text: String, language: String = "hu-HU") async {
        activateAudioSession()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.bestVoice(for: language)
        utterance.rate = rate
        utterance.preUtteranceDelay = 0.3
        utterance.postUtteranceDelay = 0.2

        isSpeaking = true
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            continuation = cont
            synthesizer.speak(utterance)
        }
        isSpeaking = false
        deactivateAudioSession()
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    /// A legjobb minőségű elérhető hang (prémium > továbbfejlesztett > alap).
    /// Jobb magyar hang letölthető: Beállítások › Kisegítő lehetőségek › Felolvasott tartalom › Hangok.
    private static func bestVoice(for language: String) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == language }
        return voices.max { $0.quality.rawValue < $1.quality.rawValue }
            ?? AVSpeechSynthesisVoice(language: language)
    }

    private func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback,
                                    mode: .spokenAudio,
                                    options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
            try session.setActive(true)
        } catch {
            print("Audio session hiba: \(error)")
        }
    }

    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session lezárási hiba: \(error)")
        }
    }

    private func finish() {
        continuation?.resume()
        continuation = nil
    }
}

extension SpeechService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.finish() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.finish() }
    }
}
