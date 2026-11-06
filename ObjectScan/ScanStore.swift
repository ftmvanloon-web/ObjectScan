import Foundation

struct ScanRecord: Identifiable, Hashable {
    let id: UUID
    let createdAt: Date
    let folder: URL
    var captureComplete: Bool

    var images: URL { folder.appendingPathComponent("Images", isDirectory: true) }
    var checkpoints: URL { folder.appendingPathComponent("Checkpoints", isDirectory: true) }
    var model: URL { folder.appendingPathComponent("Model.usdz") }
    var workingFolder: URL { folder.appendingPathComponent("Working", isDirectory: true) }
    var workingModel: URL { workingFolder.appendingPathComponent("Model.usdz") }
    var hasModel: Bool {
        let values = try? model.resourceValues(forKeys: [.fileSizeKey])
        return (values?.fileSize ?? 0) > 0
    }
    var title: String {
        "Scan " + createdAt.formatted(date: .abbreviated, time: .shortened)
    }
    var imageCount: Int {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: images, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        )) ?? []
        return files.filter { ["heic", "heif", "jpg", "jpeg", "png"].contains($0.pathExtension.lowercased()) }.count
    }
    var modelSize: String {
        let values = try? model.resourceValues(forKeys: [.fileSizeKey])
        return ByteCountFormatter.string(fromByteCount: Int64(values?.fileSize ?? 0), countStyle: .file)
    }
}

enum ScanStore {
    private struct Metadata: Codable {
        let id: UUID
        let createdAt: Date
        var captureComplete: Bool
    }

    static func root() throws -> URL {
        let documents = try FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        let root = documents.appendingPathComponent("Scans", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    static func create() throws -> ScanRecord {
        let id = UUID()
        let record = ScanRecord(
            id: id, createdAt: Date(),
            folder: try root().appendingPathComponent(id.uuidString, isDirectory: true),
            captureComplete: false
        )
        try FileManager.default.createDirectory(at: record.images, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: record.checkpoints, withIntermediateDirectories: true)
        try save(record)
        return record
    }

    static func save(_ record: ScanRecord) throws {
        let metadata = Metadata(id: record.id, createdAt: record.createdAt, captureComplete: record.captureComplete)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(metadata).write(to: record.folder.appendingPathComponent("scan.json"), options: .atomic)
    }

    static func all() throws -> [ScanRecord] {
        let folders = try FileManager.default.contentsOfDirectory(
            at: root(), includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        )
        return folders.compactMap { folder -> ScanRecord? in
            guard let data = try? Data(contentsOf: folder.appendingPathComponent("scan.json")),
                  let metadata = try? JSONDecoder().decode(Metadata.self, from: data) else { return nil }
            return ScanRecord(id: metadata.id, createdAt: metadata.createdAt, folder: folder,
                              captureComplete: metadata.captureComplete)
        }.sorted { $0.createdAt > $1.createdAt }
    }

    static func prepareOutput(_ record: ScanRecord) throws {
        // Only remove a previous, unfinished result. Keep source images and checkpoints for retries.
        if FileManager.default.fileExists(atPath: record.workingFolder.path) {
            try FileManager.default.removeItem(at: record.workingFolder)
        }
        try FileManager.default.createDirectory(at: record.workingFolder, withIntermediateDirectories: true)
    }

    static func commitModel(_ record: ScanRecord) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: record.workingModel.path)
        guard let size = attributes[.size] as? NSNumber, size.int64Value > 0 else {
            throw ScanError.missingResult
        }
        // Publish the file to the library only once RealityKit has finished writing it.
        try FileManager.default.moveItem(at: record.workingModel, to: record.model)
    }

    static func delete(_ record: ScanRecord) throws {
        try FileManager.default.removeItem(at: record.folder)
    }
}

enum ScanError: LocalizedError {
    case unsupported, cameraDenied, missingResult, interrupted

    var errorDescription: String? {
        switch self {
        case .unsupported: return "Dit apparaat ondersteunt Object Capture niet. Gebruik een iPhone met LiDAR en iOS 18 of nieuwer."
        case .cameraDenied: return "Geef ObjectScan toegang tot de camera via Instellingen."
        case .missingResult: return "Er is geen volledig 3D-model gemaakt. Probeer de bewaarde opname opnieuw te verwerken."
        case .interrupted: return "De berekening is onderbroken. Je bronbeelden zijn bewaard."
        }
    }
}
