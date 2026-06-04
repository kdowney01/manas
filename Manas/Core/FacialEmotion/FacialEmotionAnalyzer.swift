import AVFoundation
import Vision
import CoreML
import Combine
import OSLog

private let log = Logger(subsystem: "com.manas.app", category: "FacialEmotion")

// MARK: - FacialEmotionAnalyzer
//
// Two-tier inference pipeline (mirrors MAANAS AI engine architecture):
//   Tier 1 — CoreML on-device:  lightweight emotion classification (always-on)
//   Tier 2 — FACS symbolic:     Action Unit rules applied to Vision landmarks
//   Fusion — WLOP-style weighted combination of both outputs
//
// Privacy:
//   - Front camera only; no video recorded, stored, or transmitted.
//   - Only derived EmotionVector (7 probabilities) leaves this class.
//   - Analyzer stops automatically when app enters background.
//
// CoreML model:
//   Drop EmotionClassifier.mlpackage into Manas/Resources/ and add to Xcode target.
//   Convert from ONNX with:
//     import coremltools as ct
//     model = ct.converters.onnx.convert(model='emotion_model.onnx',
//                 minimum_ios_deployment_target='17')
//     model.save('EmotionClassifier.mlpackage')
//   Until the model file is present the analyzer runs FACS-only (symbolic tier).

@MainActor
final class FacialEmotionAnalyzer: NSObject, ObservableObject {

    @Published private(set) var currentEmotion: EmotionVector?
    @Published private(set) var isActive = false
    @Published private(set) var faceDetected = false
    @Published private(set) var frameReliability: Float = 0   // 0–1 quality score

    private var captureSession: AVCaptureSession?
    private let videoOutput    = AVCaptureVideoDataOutput()
    private let visionQueue    = DispatchQueue(label: "com.manas.vision", qos: .userInitiated)
    private let facsEngine     = FACSRuleEngine()
    private var coreMLModel:     VNCoreMLModel?
    private var emotionSession   = EmotionSession()

    // Throttle: process every Nth frame to stay within 100ms budget (NFR-2).
    private var frameCount = 0
    private let frameSkip  = 2   // process every 3rd frame at 30 FPS → ~10 inferences/sec

    override init() {
        super.init()
        loadCoreMLModel()
        observeAppLifecycle()
    }

    // MARK: - Lifecycle

    func start() {
        guard !isActive else { return }
        Task { await setupAndStart() }
    }

    func stop() {
        captureSession?.stopRunning()
        captureSession = nil
        emotionSession.reset()
        isActive    = false
        faceDetected = false
        currentEmotion = nil
        log.info("FacialEmotionAnalyzer stopped")
    }

    // MARK: - Private setup

    private func setupAndStart() async {
        guard await AVCaptureDevice.requestAccess(for: .video) else {
            log.info("Camera access denied — facial emotion analysis disabled")
            return
        }

        let session = AVCaptureSession()
        session.sessionPreset = .vga640x480   // low res sufficient for face analysis; saves power

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
            let input  = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            log.error("Could not configure front camera")
            return
        }

        session.addInput(input)

        videoOutput.setSampleBufferDelegate(self, queue: visionQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }

        captureSession = session

        // Run capture on a background thread to avoid blocking the main actor
        Task.detached(priority: .userInitiated) { session.startRunning() }

        isActive = true
        log.info("FacialEmotionAnalyzer started (CoreML: \(self.coreMLModel != nil ? "loaded" : "FACS-only", privacy: .public))")
    }

    private func loadCoreMLModel() {
        // Look for EmotionClassifier.mlpackage in the app bundle.
        guard let modelURL = Bundle.main.url(forResource: "EmotionClassifier", withExtension: "mlpackage") ??
                             Bundle.main.url(forResource: "EmotionClassifier", withExtension: "mlmodelc") else {
            log.info("EmotionClassifier model not found — running FACS-only mode")
            return
        }
        do {
            let mlModel = try MLModel(contentsOf: modelURL)
            coreMLModel = try VNCoreMLModel(for: mlModel)
            log.info("EmotionClassifier CoreML model loaded")
        } catch {
            log.error("Failed to load CoreML model: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Vision pipeline

    private func analyze(sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        frameCount += 1
        guard frameCount % (frameSkip + 1) == 0 else { return }

        var requests: [VNRequest] = [
            VNDetectFaceLandmarksRequest { [weak self] req, error in
                self?.handleLandmarks(req, error: error, pixelBuffer: pixelBuffer)
            }
        ]

        if let model = coreMLModel {
            requests.append(VNCoreMLRequest(model: model) { [weak self] req, error in
                self?.handleCoreMLResult(req, error: error)
            })
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: .leftMirrored)
        try? handler.perform(requests)
    }

    private func handleLandmarks(_ request: VNRequest, error: Error?, pixelBuffer: CVPixelBuffer) {
        guard error == nil,
              let obs = request.results?.first as? VNFaceObservation,
              let landmarks = obs.landmarks else {
            Task { @MainActor in self.faceDetected = false }
            return
        }

        let reliability = computeReliability(pixelBuffer: pixelBuffer, faceBox: obs.boundingBox)
        let facsVector  = facsEngine.evaluate(landmarks: landmarks, boundingBox: obs.boundingBox)

        Task { @MainActor in
            self.faceDetected      = true
            self.frameReliability  = reliability
            self.emotionSession.append(EmotionFrameResult(
                vector:      facsVector,
                confidence:  reliability,
                source:      .facsRules,
                timestamp:   Date(),
                faceDetected: true
            ))
            self.currentEmotion = self.emotionSession.smoothedVector
        }
    }

    private func handleCoreMLResult(_ request: VNRequest, error: Error?) {
        guard error == nil,
              let obs = request.results?.first as? VNClassificationObservation else { return }

        // Map CoreML classification output to EmotionVector.
        // Assumes the model outputs class labels matching the 7-class schema.
        var vector = EmotionVector()
        for result in (request.results as? [VNClassificationObservation]) ?? [] {
            switch result.identifier.lowercased() {
            case "neutral":   vector.neutral   = result.confidence
            case "happy":     vector.happy     = result.confidence
            case "sad":       vector.sad       = result.confidence
            case "angry":     vector.angry     = result.confidence
            case "fearful":   vector.fearful   = result.confidence
            case "disgusted": vector.disgusted = result.confidence
            case "surprised": vector.surprised = result.confidence
            default: break
            }
        }

        _ = obs  // suppress unused warning
        let reliability = frameReliability

        Task { @MainActor in
            self.emotionSession.append(EmotionFrameResult(
                vector:      vector,
                confidence:  reliability * 1.2,   // CoreML weighted higher than FACS
                source:      .coreml,
                timestamp:   Date(),
                faceDetected: true
            ))
            self.currentEmotion = self.emotionSession.smoothedVector
        }
    }

    // MARK: - Frame quality (reliability score)
    // Mirrors MAANAS neural_emotion_head.py estimate_confidence():
    // Rel = 0.4·Blur + 0.3·Scale + 0.3·Contrast

    private func computeReliability(pixelBuffer: CVPixelBuffer, faceBox: CGRect) -> Float {
        let scaleIndex    = min(Float(faceBox.width * faceBox.height) / (200 * 200), 1.0)
        // Blur and contrast require locking the pixel buffer — approximate with scale only
        // for perf. A more accurate version can lock the buffer and compute Laplacian.
        return min(scaleIndex * 1.2, 1.0)
    }

    // MARK: - App lifecycle: stop when backgrounded

    private func observeAppLifecycle() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.stop() }
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard self?.isActive == false else { return }
            // Don't auto-restart; caller decides when to resume
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension FacialEmotionAnalyzer: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        analyze(sampleBuffer: sampleBuffer)
    }
}
