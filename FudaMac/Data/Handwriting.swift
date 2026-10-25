import AppKit
import CoreML

// Handwritten kana: the drawing → 64×64 image step (the same as
// Tools/handwriting/preprocess.py), the Core ML model trained by
// Tools/handwriting/train.py, and the store for your own sample drawings.

enum KanaSet {
    static let hiragana = Array("あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをん").map(String.init)
    static let katakana = hiragana.map { String(UnicodeScalar($0.unicodeScalars.first!.value + 0x60)!) }
    static let romaji = "a i u e o ka ki ku ke ko sa shi su se so ta chi tsu te to na ni nu ne no ha hi fu he ho ma mi mu me mo ya yu yo ra ri ru re ro wa wo n".split(separator: " ").map(String.init)
    static var all: [String] { hiragana + katakana }
    static func romaji(_ k: String) -> String {
        if let i = hiragana.firstIndex(of: k) { return romaji[i] }
        if let i = katakana.firstIndex(of: k) { return romaji[i] }
        return k
    }
    static func isKatakana(_ k: String) -> Bool { katakana.contains(k) }
    /// Drawn identically in both scripts, so either answer counts.
    static func sameShape(_ a: String, _ b: String) -> Bool { a == b || Set([a, b]) == ["へ", "ヘ"] }
}

/// The drawing, turned into exactly what the model was trained on:
/// ink bright on black → crop to the ink → square with a margin → 64×64, scaled so the brightest pixel is 1.
enum HandwritingPrep {
    static let size = 64
    static let margin: CGFloat = 0.15      // = MARGIN in preprocess.py

    static func pixels(_ strokes: [[CGPoint]], lineWidth: CGFloat) -> [Float]? {
        let pts = strokes.flatMap { $0 }
        guard let minX = pts.map(\.x).min(), let maxX = pts.map(\.x).max(),
              let minY = pts.map(\.y).min(), let maxY = pts.map(\.y).max() else { return nil }
        // Ink bounds include the pen's thickness.
        let r = lineWidth / 2
        let box = CGRect(x: minX - r, y: minY - r, width: maxX - minX + lineWidth, height: maxY - minY + lineWidth)
        let side = max(box.width, box.height) * (1 + 2 * margin)
        let scale = CGFloat(size) / side
        guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        ctx.setFillColor(gray: 0, alpha: 1); ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
        // View coordinates have y down; the bitmap has y up.
        ctx.translateBy(x: 0, y: CGFloat(size)); ctx.scaleBy(x: 1, y: -1)
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: -box.midX + side / 2, y: -box.midY + side / 2)
        ctx.setStrokeColor(gray: 1, alpha: 1); ctx.setLineWidth(lineWidth)
        ctx.setLineCap(.round); ctx.setLineJoin(.round)
        ctx.setShouldAntialias(true); ctx.interpolationQuality = .high
        for s in strokes where !s.isEmpty {
            ctx.beginPath(); ctx.move(to: s[0])
            if s.count == 1 { ctx.addLine(to: CGPoint(x: s[0].x + 0.1, y: s[0].y)) }
            for p in s.dropFirst() { ctx.addLine(to: p) }
            ctx.strokePath()
        }
        guard let data = ctx.data else { return nil }
        let bytes = data.bindMemory(to: UInt8.self, capacity: size * size)
        var out = (0..<(size * size)).map { Float(bytes[$0]) / 255 }
        let m = out.max() ?? 1
        if m > 0 { out = out.map { $0 / m } }
        return out
    }

    /// The 64×64 input as an image, to show "what the model sees".
    static func image(_ px: [Float]) -> NSImage {
        let bytes = px.map { UInt8(max(0, min(255, $0 * 255))) }
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 1,
                                   hasAlpha: false, isPlanar: false, colorSpaceName: .deviceWhite, bytesPerRow: size, bitsPerPixel: 8)!
        bytes.withUnsafeBufferPointer { src in rep.bitmapData!.update(from: src.baseAddress!, count: bytes.count) }
        let img = NSImage(size: NSSize(width: size, height: size)); img.addRepresentation(rep)
        return img
    }

    /// The full drawing (white on black, canvas size) as PNG, for your own test set.
    static func png(_ strokes: [[CGPoint]], canvas: CGFloat, lineWidth: CGFloat) -> Data? {
        let n = Int(canvas)
        guard let ctx = CGContext(data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        ctx.setFillColor(gray: 0, alpha: 1); ctx.fill(CGRect(x: 0, y: 0, width: n, height: n))
        ctx.translateBy(x: 0, y: CGFloat(n)); ctx.scaleBy(x: 1, y: -1)
        ctx.setStrokeColor(gray: 1, alpha: 1); ctx.setLineWidth(lineWidth); ctx.setLineCap(.round); ctx.setLineJoin(.round)
        for s in strokes where !s.isEmpty {
            ctx.beginPath(); ctx.move(to: s[0])
            if s.count == 1 { ctx.addLine(to: CGPoint(x: s[0].x + 0.1, y: s[0].y)) }
            for p in s.dropFirst() { ctx.addLine(to: p) }
            ctx.strokePath()
        }
        guard let cg = ctx.makeImage() else { return nil }
        return NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])
    }
}

/// The trained model (Resources/KanaRecognizer.mlpackage, compiled by Xcode). Absent until you train one.
final class KanaReader {
    static let shared = KanaReader()
    let model: MLModel?

    private init() {
        if let url = Bundle.main.url(forResource: "KanaRecognizer", withExtension: "mlmodelc") {
            let cfg = MLModelConfiguration(); cfg.computeUnits = .all
            model = try? MLModel(contentsOf: url, configuration: cfg)
        } else {
            model = nil
        }
    }

    var available: Bool { model != nil }

    /// Top guesses with their probabilities, best first.
    func read(_ px: [Float], top: Int = 3) -> [(kana: String, p: Double)] {
        guard let model, px.count == HandwritingPrep.size * HandwritingPrep.size,
              let arr = try? MLMultiArray(shape: [1, 1, 64, 64], dataType: .float32) else { return [] }
        for (i, v) in px.enumerated() { arr[i] = NSNumber(value: v) }
        let input = try? MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(multiArray: arr)])
        guard let input, let out = try? model.prediction(from: input) else { return [] }
        let probsName = model.modelDescription.predictedProbabilitiesName ?? ""
        guard let probs = out.featureValue(for: probsName)?.dictionaryValue as? [String: NSNumber] else { return [] }
        return probs.map { ($0.key, $0.value.doubleValue) }.sorted { $0.1 > $1.1 }.prefix(top).map { ($0.0, $0.1) }
    }
}

/// Your own drawings, saved as Application Support/Handwriting/samples/<kana>/<time>.png —
/// the "real world" test set for Tools/handwriting/eval_folder.py.
@Observable
final class HandwritingSamples {
    private(set) var counts: [String: Int] = [:]
    let dir: URL

    init() {
        dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Handwriting/samples", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        refresh()
    }

    func refresh() {
        var c: [String: Int] = [:]
        for k in KanaSet.all {
            let d = dir.appendingPathComponent(k, isDirectory: true)
            c[k] = ((try? FileManager.default.contentsOfDirectory(atPath: d.path)) ?? []).filter { $0.hasSuffix(".png") }.count
        }
        counts = c
    }

    var total: Int { counts.values.reduce(0, +) }

    func save(_ png: Data, kana: String) {
        let d = dir.appendingPathComponent(kana, isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        let name = "\(Int(Date().timeIntervalSince1970 * 1000)).png"
        try? png.write(to: d.appendingPathComponent(name))
        counts[kana, default: 0] += 1
    }

    func undoLast(_ kana: String) {
        let d = dir.appendingPathComponent(kana, isDirectory: true)
        let files = ((try? FileManager.default.contentsOfDirectory(atPath: d.path)) ?? []).filter { $0.hasSuffix(".png") }.sorted()
        guard let last = files.last else { return }
        try? FileManager.default.removeItem(at: d.appendingPathComponent(last))
        counts[kana] = max(0, (counts[kana] ?? 1) - 1)
    }

    func reveal() { NSWorkspace.shared.activateFileViewerSelecting([dir]) }
}
