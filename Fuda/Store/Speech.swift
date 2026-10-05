import AVFoundation

/// Japanese text-to-speech via the system voices.
final class Speech: NSObject, AVSpeechSynthesizerDelegate {
    enum Voice { case main, partner }

    static let shared = Speech()
    private let synth = AVSpeechSynthesizer()
    var rate: Float = 0.42

    private var current: AVSpeechUtterance?
    private var onFinish: (() -> Void)?

    /// Up to two distinct Japanese voices, best quality first, so a dialogue
    /// can give "them" and "you" different voices.
    private lazy var voices: [AVSpeechSynthesisVoice] = {
        let ja = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "ja-JP" }
            .sorted { $0.quality.rawValue > $1.quality.rawValue }
        var picked: [AVSpeechSynthesisVoice] = []
        for v in ja where !picked.contains(where: { $0.name == v.name }) { picked.append(v) }
        if picked.isEmpty, let v = AVSpeechSynthesisVoice(language: "ja-JP") { picked = [v] }
        return Array(picked.prefix(2))
    }()

    private override init() {
        super.init()
        synth.delegate = self
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        #endif
    }

    func say(_ text: String, rate: Float? = nil, voice: Voice = .main, completion: (() -> Void)? = nil) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { completion?(); return }
        stop()
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        let u = AVSpeechUtterance(string: t)
        switch voice {
        case .main:
            u.voice = voices.first
        case .partner:
            // A second voice when the device has one; otherwise shift the pitch.
            if voices.count > 1 { u.voice = voices[1] } else { u.voice = voices.first; u.pitchMultiplier = 0.85 }
        }
        u.rate = rate ?? self.rate
        current = u
        onFinish = completion
        synth.speak(u)
    }

    func stop() {
        current = nil
        onFinish = nil
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
    }

    var isSpeaking: Bool { synth.isSpeaking }

    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        guard u === current else { return }
        let done = onFinish
        current = nil
        onFinish = nil
        DispatchQueue.main.async { done?() }
    }
}
