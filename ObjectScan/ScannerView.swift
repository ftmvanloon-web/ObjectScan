import RealityKit
import SwiftUI

@MainActor
struct ScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: ScannerModel
    @State private var confirmStop = false

    init(record: ScanRecord) { _model = State(initialValue: ScannerModel(record: record)) }

    var body: some View {
        NavigationStack {
            Group {
                switch model.stage {
                case .preparing:
                    ProgressView("Camera voorbereiden…")
                case .capturing:
                    if let session = model.captureSession { captureView(session) }
                case .reconstructing:
                    processingView
                case .finished:
                    finishedView
                case .failed:
                    failureView
                case .cancelled:
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Object scannen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(model.stage == .finished || model.stage == .failed ? "Sluiten" : "Stoppen") {
                        if model.stage == .finished || model.stage == .failed {
                            model.cancel()
                            dismiss()
                        } else { confirmStop = true }
                    }
                }
            }
            .confirmationDialog("Deze scan stoppen?", isPresented: $confirmStop, titleVisibility: .visible) {
                Button("Stoppen", role: .destructive) { model.cancel(); dismiss() }
                Button("Doorgaan", role: .cancel) {}
            } message: {
                Text("Een volledig afgeronde opname blijft bewaard om later opnieuw te berekenen.")
            }
            .task { await model.prepare() }
            .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
                model.cancel()
            }
            .onChange(of: scenePhase) { _, phase in
                model.setActive(phase == .active)
                UIApplication.shared.isIdleTimerDisabled = phase == .active
            }
        }
    }

    private func captureView(_ session: ObjectCaptureSession) -> some View {
        ObjectCaptureView(session: session)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Text(instruction(for: session))
                        .font(.subheadline).multilineTextAlignment(.center)
                    if let feedback = feedback(for: session) {
                        Text(feedback).font(.subheadline.bold()).foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                    }
                    if let guidance = model.guidance {
                        Text(guidance).font(.caption).multilineTextAlignment(.center)
                    }
                    controls(for: session)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.regularMaterial)
            }
    }

    @ViewBuilder
    private func controls(for session: ObjectCaptureSession) -> some View {
        switch session.state {
        case .ready:
            Button("Object herkennen", systemImage: "viewfinder") { model.detectObject() }
                .buttonStyle(.borderedProminent).controlSize(.large)
        case .detecting:
            HStack {
                Button("Opnieuw") { _ = session.resetDetection() }
                    .buttonStyle(.bordered)
                Button("Start scannen") { model.startCapturing() }
                    .buttonStyle(.borderedProminent)
            }
        case .capturing:
            Text("\(session.numberOfShotsTaken) / \(session.maximumNumberOfInputImages) foto’s")
                .font(.caption.monospacedDigit())
            HStack {
                Button("Extra foto", systemImage: "camera") { session.requestImageCapture() }
                    .buttonStyle(.bordered)
                    .disabled(!session.canRequestImageCapture || session.numberOfShotsTaken >= session.maximumNumberOfInputImages)
                Button("Maak 3D-model", systemImage: "cube") { model.finishCapture() }
                    .buttonStyle(.borderedProminent)
                    .disabled(session.numberOfShotsTaken < 20)
            }
            if session.userCompletedScanPass, session.numberOfShotsTaken < session.maximumNumberOfInputImages {
                Button("Nog een ronde, hoger of lager", systemImage: "arrow.triangle.2.circlepath") {
                    session.beginNewScanPass()
                }
                .buttonStyle(.bordered)
            }
        case .initializing, .finishing:
            ProgressView(session.state == .finishing ? "Opname opslaan…" : "Even voorbereiden…")
        default: EmptyView()
        }
    }

    private var processingView: some View {
        VStack(spacing: 22) {
            Image(systemName: "cube.transparent").font(.system(size: 64)).foregroundStyle(.teal)
            Text("Je 3D-model wordt gemaakt").font(.title2.bold())
            ProgressView(value: model.progress)
            Text(model.progress, format: .percent.precision(.fractionLength(0)))
                .font(.title3.monospacedDigit())
            Text(model.status).foregroundStyle(.secondary)
            Text("Laat de app open. Dit kan enkele minuten duren en je iPhone kan warm worden.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if model.skippedImages > 0 {
                Text("\(model.skippedImages) foto’s konden niet worden gebruikt.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(30)
    }

    private var finishedView: some View {
        VStack(spacing: 22) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 64)).foregroundStyle(.teal)
            Text("Je scan is opgeslagen").font(.title2.bold())
            Text("Exporteer het USDZ-bestand naar Bestanden, je pc of een andere app.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            ShareLink(item: model.record.model) {
                Label("Exporteer 3D-model", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            Button("Terug naar mijn scans") { dismiss() }.buttonStyle(.bordered)
        }
        .padding(30)
    }

    private var failureView: some View {
        VStack(spacing: 22) {
            Image(systemName: "exclamationmark.triangle").font(.system(size: 54)).foregroundStyle(.orange)
            Text("Scannen is niet gelukt").font(.title2.bold())
            Text(model.errorMessage ?? "Probeer een nieuwe scan.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            if model.cameraDenied {
                Button("Open instellingen") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }.buttonStyle(.borderedProminent)
            }
            if model.record.captureComplete {
                Text("Je bronbeelden zijn bewaard.").font(.footnote)
                Button("Berekening opnieuw proberen") { model.beginReconstruction() }
                    .buttonStyle(.borderedProminent)
            }
            Button("Terug naar mijn scans") { dismiss() }.buttonStyle(.bordered)
        }
        .padding(30)
    }

    private func instruction(for session: ObjectCaptureSession) -> String {
        switch session.state {
        case .ready: return "Zet je object stil neer, zorg voor veel egaal licht en neem het helemaal in beeld."
        case .detecting: return "Pas het kader aan zodat alleen je object erin past."
        case .capturing:
            if session.numberOfShotsTaken >= session.maximumNumberOfInputImages {
                return "Het fotolimiet is bereikt. Maak nu je 3D-model."
            }
            return "Loop langzaam om het object. Maak ook een ronde van boven en van onderen. Minimaal 20 foto’s; meer hoeken geven een vollediger model."
        default: return "Houd je iPhone rustig."
        }
    }

    private func feedback(for session: ObjectCaptureSession) -> String? {
        let feedback = session.feedback
        if feedback.contains(.environmentTooDark) { return "Het is te donker. Zorg voor meer licht." }
        if feedback.contains(.environmentLowLight) { return "Meer licht geeft scherpere foto’s." }
        if feedback.contains(.objectTooClose) { return "Neem wat meer afstand." }
        if feedback.contains(.objectTooFar) { return "Kom iets dichterbij." }
        if feedback.contains(.movingTooFast) { return "Beweeg langzamer." }
        if feedback.contains(.outOfFieldOfView) { return "Breng het hele object weer in beeld." }
        if feedback.contains(.objectNotDetected) { return "Het object is nog niet herkend." }
        return nil
    }
}
