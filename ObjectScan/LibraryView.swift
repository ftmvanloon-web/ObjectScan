import QuickLook
import SwiftUI

@MainActor
struct LibraryView: View {
    @State private var scans: [ScanRecord] = []
    @State private var activeScan: ScanRecord?
    @State private var previewScan: ScanRecord?
    @State private var pendingDelete: ScanRecord?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Van object naar 3D", systemImage: "viewfinder")
                            .font(.title2.bold())
                        Text("Loop met je iPhone om een stilstaand object heen. Foto’s en LiDAR werken samen; de berekening gebeurt op je iPhone.")
                            .foregroundStyle(.secondary)
                        Button("Nieuw object scannen", systemImage: "plus.viewfinder") { newScan() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                    }
                    .padding(.vertical, 8)
                }
                Section("Je scans") {
                    if scans.isEmpty {
                        Text("Je opgeslagen modellen verschijnen hier.").foregroundStyle(.secondary)
                    }
                    ForEach(scans) { scan in
                        VStack(alignment: .leading, spacing: 8) {
                            Label(scan.title, systemImage: scan.hasModel ? "cube" : "camera")
                                .font(.headline)
                            if scan.hasModel {
                                Text("USDZ · \(scan.modelSize) · \(scan.imageCount) bronfoto’s")
                                    .font(.caption).foregroundStyle(.secondary)
                                HStack(spacing: 24) {
                                    Button("Bekijken", systemImage: "cube.transparent") { previewScan = scan }
                                    ShareLink(item: scan.model) { Label("Exporteren", systemImage: "square.and.arrow.up") }
                                }
                                .buttonStyle(.borderless)
                            } else if scan.captureComplete {
                                Text("Opname bewaard · \(scan.imageCount) bronfoto’s")
                                    .font(.caption).foregroundStyle(.secondary)
                                Button("3D-model berekenen", systemImage: "arrow.clockwise") { activeScan = scan }
                                    .buttonStyle(.borderless)
                            } else {
                                Text("Onvolledige opname. Start een nieuwe scan; je kunt deze opname verwijderen.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                        .swipeActions {
                            Button("Verwijderen", role: .destructive) { pendingDelete = scan }
                        }
                    }
                }
                Section {
                    Text("Alles blijft lokaal. Exporteer belangrijke scans ook naar Bestanden of je pc. Bronfoto’s blijven bewaard voor een nieuwe berekening en nemen opslagruimte in.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("ObjectScan")
            .task { reload() }
            .refreshable { reload() }
            .fullScreenCover(item: $activeScan, onDismiss: reload) { scan in
                ScannerView(record: scan)
            }
            .sheet(item: $previewScan) { scan in
                NavigationStack {
                    ModelPreview(url: scan.model)
                        .navigationTitle("3D-model")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Gereed") { previewScan = nil }
                            }
                        }
                }
            }
            .confirmationDialog("Scan en bronfoto’s verwijderen?", isPresented: Binding(
                get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }
            ), titleVisibility: .visible) {
                Button("Verwijderen", role: .destructive) {
                    if let scan = pendingDelete {
                        do { try ScanStore.delete(scan); reload() }
                        catch { errorMessage = error.localizedDescription }
                    }
                    pendingDelete = nil
                }
                Button("Annuleren", role: .cancel) { pendingDelete = nil }
            }
            .alert("Er ging iets mis", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    private func newScan() {
        do { activeScan = try ScanStore.create() }
        catch { errorMessage = error.localizedDescription }
    }

    private func reload() {
        do { scans = try ScanStore.all() }
        catch { errorMessage = error.localizedDescription }
    }
}

struct ModelPreview: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: QLPreviewController, context: Context) {}

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}
