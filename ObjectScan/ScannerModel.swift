import AVFoundation
import Observation
import RealityKit
import SwiftUI

@MainActor
@Observable
final class ScannerModel {
    enum Stage: Equatable { case preparing, capturing, reconstructing, finished, failed, cancelled }

    private(set) var record: ScanRecord
    private(set) var stage: Stage = .preparing
    private(set) var captureSession: ObjectCaptureSession?
    private(set) var progress: Double = 0
    private(set) var status = "Camera voorbereiden…"
    private(set) var errorMessage: String?
    private(set) var cameraDenied = false
    private(set) var skippedImages = 0
    var guidance: String?

    @ObservationIgnored private var prepared = false
    @ObservationIgnored private var stateTask: Task<Void, Never>?
    @ObservationIgnored private var reconstructionTask: Task<Void, Never>?
    @ObservationIgnored private var reconstructionSession: PhotogrammetrySession?

    init(record: ScanRecord) { self.record = record }

    func prepare() async {
        guard !prepared else { return }
        prepared = true
        guard ObjectCaptureSession.isSupported, PhotogrammetrySession.isSupported else {
            fail(ScanError.unsupported)
            return
        }
        if record.captureComplete {
            beginReconstruction()
            return
        }
        let authorized: Bool
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: authorized = true
        case .notDetermined: authorized = await AVCaptureDevice.requestAccess(for: .video)
        default: authorized = false
        }
        guard !Task.isCancelled, stage != .cancelled else { return }
        guard authorized else {
            cameraDenied = true
            fail(ScanError.cameraDenied)
            return
        }
        let session = ObjectCaptureSession()
        var configuration = ObjectCaptureSession.Configuration()
        configuration.checkpointDirectory = record.checkpoints
        configuration.isOverCaptureEnabled = false
        captureSession = session
        stage = .capturing
        stateTask = Task { [weak self, session] in
            for await state in session.stateUpdates {
                guard !Task.isCancelled else { return }
                self?.captureStateChanged(state)
                switch state {
                case .completed, .failed: return
                default: break
                }
            }
        }
        session.start(imagesDirectory: record.images, configuration: configuration)
        captureStateChanged(session.state)
    }

    func detectObject() {
        guard let session = captureSession, session.state == .ready else { return }
        guidance = session.startDetecting() ? nil : "Houd het hele object in beeld en probeer het opnieuw."
    }

    func startCapturing() {
        guard let session = captureSession, session.state == .detecting else { return }
        guidance = nil
        session.startCapturing()
    }

    func finishCapture() {
        guard let session = captureSession, session.state == .capturing,
              session.numberOfShotsTaken >= 20 else { return }
        session.finish()
    }

    func setActive(_ active: Bool) {
        guard stage == .capturing, let session = captureSession else { return }
        if active {
            if session.isPaused { session.resume() }
        } else if session.state == .capturing || session.state == .detecting {
            session.pause()
        }
    }

    func beginReconstruction() {
        guard record.captureComplete, stage != .reconstructing, stage != .finished else { return }
        stateTask?.cancel()
        stateTask = nil
        captureSession = nil
        stage = .reconstructing
        errorMessage = nil
        progress = 0
        skippedImages = 0
        status = "Foto’s en dieptegegevens inlezen…"
        reconstructionTask = Task { [weak self] in
            await self?.reconstruct()
        }
    }

    func cancel() {
        if stage != .finished { stage = .cancelled }
        stateTask?.cancel()
        stateTask = nil
        reconstructionTask?.cancel()
        reconstructionTask = nil
        captureSession?.cancel()
        captureSession = nil
        reconstructionSession?.cancel()
        reconstructionSession = nil
    }

    private func captureStateChanged(_ state: ObjectCaptureSession.CaptureState) {
        guard stage == .capturing else { return }
        switch state {
        case .completed:
            do {
                record.captureComplete = true
                try ScanStore.save(record)
                beginReconstruction()
            } catch { fail(error) }
        case .failed(let error): fail(error)
        default: break
        }
    }

    private func reconstruct() async {
        defer { reconstructionSession = nil }
        do {
            try Task.checkCancellation()
            try ScanStore.prepareOutput(record)
            var configuration = PhotogrammetrySession.Configuration()
            configuration.checkpointDirectory = record.checkpoints
            let session = try PhotogrammetrySession(input: record.images, configuration: configuration)
            reconstructionSession = session
            // iOS supports the reduced detail level, including the object's textures.
            let request = PhotogrammetrySession.Request.modelFile(
                url: record.workingModel, detail: .reduced, geometry: nil
            )
            try session.process(requests: [request])
            for try await output in session.outputs {
                try Task.checkCancellation()
                guard stage == .reconstructing else {
                    session.cancel()
                    return
                }
                switch output {
                case .requestProgress(_, let fraction):
                    progress = min(max(fraction, 0), 1)
                case .inputComplete:
                    status = "3D-model en texturen berekenen…"
                case .requestError(_, let error):
                    session.cancel()
                    throw error
                case .invalidSample, .skippedSample:
                    skippedImages += 1
                case .processingComplete:
                    try ScanStore.commitModel(record)
                    progress = 1
                    stage = .finished
                    return
                case .processingCancelled:
                    throw ScanError.interrupted
                default: break
                }
            }
            throw ScanError.missingResult
        } catch {
            reconstructionSession?.cancel()
            if !Task.isCancelled, stage != .cancelled { fail(error) }
        }
    }

    private func fail(_ error: Error) {
        errorMessage = error.localizedDescription
        stage = .failed
        captureSession?.cancel()
        captureSession = nil
        stateTask?.cancel()
        stateTask = nil
    }
}
