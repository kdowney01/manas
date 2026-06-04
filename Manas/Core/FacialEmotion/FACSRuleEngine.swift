import Vision

// MARK: - FACSRuleEngine
// Symbolic layer: maps VNFaceLandmarks2D geometry to Ekman FACS Action Units,
// then combines AUs into emotion probability estimates.
//
// This mirrors the MAANAS Python emotion_detector.py FACS evaluator.
// Geometry-based AU detection from Vision landmark points.
//
// Reference: Ekman & Friesen (1978) Facial Action Coding System.

final class FACSRuleEngine {

    // MARK: - Public entry point

    func evaluate(landmarks: VNFaceLandmarks2D, boundingBox: CGRect) -> EmotionVector {
        let aus = detectActionUnits(landmarks: landmarks, boundingBox: boundingBox)
        return combineAUs(aus)
    }

    // MARK: - Action Unit detection

    private struct AUs {
        var au1:  Float = 0   // Inner brow raise
        var au2:  Float = 0   // Outer brow raise
        var au4:  Float = 0   // Brow lowerer
        var au5:  Float = 0   // Upper lid raiser
        var au6:  Float = 0   // Cheek raiser
        var au7:  Float = 0   // Lid tightener
        var au9:  Float = 0   // Nose wrinkler
        var au12: Float = 0   // Lip corner puller (smile)
        var au15: Float = 0   // Lip corner depressor
        var au17: Float = 0   // Chin raiser
        var au20: Float = 0   // Lip stretcher
        var au23: Float = 0   // Lip tightener
        var au25: Float = 0   // Lips part
        var au26: Float = 0   // Jaw drop
    }

    private func detectActionUnits(landmarks: VNFaceLandmarks2D, boundingBox: CGRect) -> AUs {
        var aus = AUs()
        let faceH = boundingBox.height
        guard faceH > 0 else { return aus }

        // Normalise all measurements relative to face height for scale invariance.
        func norm(_ v: CGFloat) -> Float { Float(v / faceH) }

        // ── Brow region ──────────────────────────────────────────────────────────

        if let leftBrow  = landmarks.leftEyebrow?.normalizedPoints,
           let leftEye   = landmarks.leftEye?.normalizedPoints,
           leftBrow.count >= 4, leftEye.count >= 4 {

            // AU4: brow lowerer — inner brow close to inner eye corner
            let innerBrowY  = leftBrow[0].y
            let innerEyeY   = leftEye[1].y
            let browDrop    = norm(innerEyeY - innerBrowY)
            aus.au4 = clamp(1.0 - browDrop * 8.0)

            // AU1: inner brow raise — inner brow elevated above neutral
            aus.au1 = clamp(browDrop * 6.0 - 0.2)

            // AU2: outer brow raise
            let outerBrowY = leftBrow.last?.y ?? innerBrowY
            let outerEyeY  = leftEye[0].y
            aus.au2 = clamp(Float(outerBrowY - outerEyeY) * 10.0)
        }

        // ── Eye region ───────────────────────────────────────────────────────────

        if let leftEye = landmarks.leftEye?.normalizedPoints, leftEye.count >= 6 {
            // AU5: upper lid raiser — eye openness (vertical span)
            let eyeOpen = norm(leftEye[1].y - leftEye[4].y)
            aus.au5 = clamp(eyeOpen * 12.0 - 0.4)

            // AU7: lid tightener — compressed eye opening
            aus.au7 = clamp(0.6 - eyeOpen * 10.0)
        }

        // ── Nose ─────────────────────────────────────────────────────────────────

        if let nose     = landmarks.nose?.normalizedPoints,
           let noseCrest = landmarks.noseCrest?.normalizedPoints,
           nose.count >= 3, noseCrest.count >= 3 {
            let noseWidth = norm(nose.last!.x - nose.first!.x)
            let crestWidth = norm(noseCrest.last!.x - noseCrest.first!.x)
            // AU9: nose wrinkler — nose bridge narrows
            aus.au9 = clamp((crestWidth - noseWidth) * 15.0)
        }

        // ── Mouth region ─────────────────────────────────────────────────────────

        if let outerLips = landmarks.outerLips?.normalizedPoints,
           let innerLips = landmarks.innerLips?.normalizedPoints,
           outerLips.count >= 8, innerLips.count >= 4 {

            let leftCorner  = outerLips[0]
            let rightCorner = outerLips[6]
            let topCenter   = outerLips[3]
            let botCenter   = outerLips.count > 9 ? outerLips[9] : outerLips[7]

            // Corner angle: positive = corners up (smile), negative = corners down
            let avgCornerY  = (leftCorner.y + rightCorner.y) / 2
            let centerY     = topCenter.y
            let cornerAngle = Float(avgCornerY - centerY)

            // AU12: lip corner puller (smile)
            aus.au12 = clamp(cornerAngle * 20.0)

            // AU15: lip corner depressor (sadness)
            aus.au15 = clamp(-cornerAngle * 20.0)

            // AU6: cheek raiser — accompanies genuine smile (Duchenne marker)
            // Approximated by high AU12 combined with narrowed eyes
            aus.au6 = clamp(aus.au12 * (1.0 - aus.au7))

            // Mouth openness
            let mouthOpen = norm(botCenter.y - topCenter.y)

            // AU25: lips part
            aus.au25 = clamp(mouthOpen * 15.0 - 0.3)

            // AU26: jaw drop (large opening)
            aus.au26 = clamp(mouthOpen * 20.0 - 1.0)

            // AU20: lip stretcher — wide mouth, corners retracted
            let mouthWidth = norm(rightCorner.x - leftCorner.x)
            aus.au20 = clamp(mouthWidth * 4.0 - 1.5)

            // AU17: chin raiser — inner lip shape compressed upward
            if innerLips.count >= 4 {
                let innerOpen = norm(innerLips[2].y - innerLips[0].y)
                aus.au17 = clamp(0.5 - innerOpen * 8.0)
            }

            // AU23: lip tightener — approximated by narrow inner lip opening
            aus.au23 = clamp(1.0 - aus.au25 * 2.0)
        }

        return aus
    }

    // MARK: - AU → emotion combination rules
    // Based on Ekman's universal affect program:
    // Happiness  = AU6 + AU12
    // Sadness    = AU1 + AU4 + AU15 + AU17
    // Anger      = AU4 + AU5 + AU7 + AU23 + AU24
    // Fear       = AU1 + AU2 + AU5B + AU20 + AU26
    // Disgust    = AU9 + AU15 + AU16 + AU25
    // Surprise   = AU1 + AU2 + AU5 + AU26
    // Neutral    = residual

    private func combineAUs(_ aus: AUs) -> EmotionVector {
        var v = EmotionVector()

        v.happy     = clamp((aus.au6 * 0.4 + aus.au12 * 0.6))
        v.sad       = clamp((aus.au1 * 0.25 + aus.au4 * 0.25 + aus.au15 * 0.35 + aus.au17 * 0.15))
        v.angry     = clamp((aus.au4 * 0.30 + aus.au5 * 0.15 + aus.au7 * 0.20 + aus.au23 * 0.35))
        v.fearful   = clamp((aus.au1 * 0.20 + aus.au2 * 0.20 + aus.au5 * 0.20 + aus.au20 * 0.20 + aus.au26 * 0.20))
        v.disgusted = clamp((aus.au9 * 0.35 + aus.au15 * 0.25 + aus.au25 * 0.10 + aus.au17 * 0.30))
        v.surprised = clamp((aus.au1 * 0.20 + aus.au2 * 0.20 + aus.au5 * 0.25 + aus.au26 * 0.35))

        // Neutral is the residual after removing all detected affect
        let affect = v.happy + v.sad + v.angry + v.fearful + v.disgusted + v.surprised
        v.neutral  = clamp(1.0 - affect)

        return normalize(v)
    }

    // MARK: - Helpers

    private func clamp(_ v: Float) -> Float { max(0, min(1, v)) }

    private func normalize(_ v: EmotionVector) -> EmotionVector {
        let total = v.neutral + v.happy + v.sad + v.angry + v.fearful + v.disgusted + v.surprised
        guard total > 0 else { return v }
        var n = v
        n.neutral   /= total
        n.happy     /= total
        n.sad       /= total
        n.angry     /= total
        n.fearful   /= total
        n.disgusted /= total
        n.surprised /= total
        return n
    }
}
