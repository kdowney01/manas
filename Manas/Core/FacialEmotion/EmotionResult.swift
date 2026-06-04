import Foundation

// MARK: - EmotionVector
// 7-class probability distribution matching the MAANAS ONNX model output.
// Values are softmax probabilities summing to ~1.0.

struct EmotionVector: Codable, Equatable {
    var neutral:   Float = 0
    var happy:     Float = 0
    var sad:       Float = 0
    var angry:     Float = 0
    var fearful:   Float = 0
    var disgusted: Float = 0
    var surprised: Float = 0

    // Dominant emotion label and confidence
    var dominant: (label: String, confidence: Float) {
        let all: [(String, Float)] = [
            ("neutral", neutral), ("happy", happy), ("sad", sad),
            ("angry", angry), ("fearful", fearful), ("disgusted", disgusted),
            ("surprised", surprised)
        ]
        return all.max(by: { $0.1 < $1.1 }) ?? ("neutral", 0)
    }

    // Composite stress signal: elevated fear + anger + disgust relative to neutral
    // Maps to the MAANAS rPPG stress index concept.
    var stressSignal: Float {
        let distress = fearful + angry + disgusted
        let baseline = neutral + happy
        guard baseline > 0 else { return 0 }
        return min(distress / (distress + baseline), 1.0)
    }

    // Pain/discomfort indicator (used in MAANAS pain scoring)
    var painIndicator: Float {
        min((fearful * 0.4 + angry * 0.3 + disgusted * 0.3), 1.0)
    }

    // Returns a dictionary for JSON telemetry (no raw values — only dominant label)
    var telemetrySummary: [String: String] {
        ["dominant": dominant.label, "stressSignal": String(format: "%.2f", stressSignal)]
    }
}

// MARK: - EmotionFrameResult
// Output of a single camera frame analysis pass.

struct EmotionFrameResult {
    enum Source { case coreml, facsRules, fused }

    let vector:     EmotionVector
    let confidence: Float        // frame reliability score (blur + scale + contrast)
    let source:     Source
    let timestamp:  Date
    let faceDetected: Bool
}

// MARK: - EmotionSession
// Rolling window of recent frame results used to smooth the signal.

struct EmotionSession {
    private var frames: [EmotionFrameResult] = []
    private let windowSize = 30   // ~1 second at 30 FPS

    mutating func append(_ result: EmotionFrameResult) {
        frames.append(result)
        if frames.count > windowSize { frames.removeFirst() }
    }

    // Confidence-weighted average over the rolling window
    var smoothedVector: EmotionVector? {
        let valid = frames.filter { $0.faceDetected && $0.confidence > 0.3 }
        guard !valid.isEmpty else { return nil }

        let totalWeight = valid.map(\.confidence).reduce(0, +)
        guard totalWeight > 0 else { return nil }

        var result = EmotionVector()
        for frame in valid {
            let w = frame.confidence / totalWeight
            result.neutral   += frame.vector.neutral   * w
            result.happy     += frame.vector.happy     * w
            result.sad       += frame.vector.sad       * w
            result.angry     += frame.vector.angry     * w
            result.fearful   += frame.vector.fearful   * w
            result.disgusted += frame.vector.disgusted * w
            result.surprised += frame.vector.surprised * w
        }
        return result
    }

    mutating func reset() { frames = [] }
}
