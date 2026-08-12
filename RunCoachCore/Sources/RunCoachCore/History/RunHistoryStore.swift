import Foundation

/// Persiste `CompletedRun`s como archivos JSON en un directorio — un
/// archivo por carrera, nombrado por su `id`. Usa `FileManager`, que es
/// parte de Foundation y está disponible en Windows/Linux, así que esto
/// se puede testear en Windows con un directorio temporal (ver
/// `RunHistoryStoreTests`), sin ningún framework de Apple. La decisión de
/// *qué directorio real* usar en el iPhone (Documents) vive en
/// `RunCoach-iOS`, no acá — este store solo sabe leer/escribir en el
/// directorio que le pasen.
public final class RunHistoryStore {
    private let directory: URL
    private let fileManager: FileManager

    public init(directory: URL, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func save(_ run: CompletedRun) throws {
        let data = try JSONEncoder().encode(run)
        try data.write(to: fileURL(for: run.id), options: .atomic)
    }

    /// Todas las carreras guardadas, más reciente primero. Ignora
    /// silenciosamente cualquier archivo que no sea un `CompletedRun`
    /// válido (por ejemplo, restos de una versión anterior del formato)
    /// en vez de fallar toda la lista por uno solo.
    public func loadAll() -> [CompletedRun] {
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }

        let runs = files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> CompletedRun? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode(CompletedRun.self, from: data)
            }

        return runs.sorted { $0.startedAt > $1.startedAt }
    }

    public func delete(_ run: CompletedRun) throws {
        try fileManager.removeItem(at: fileURL(for: run.id))
    }

    private func fileURL(for id: UUID) -> URL {
        directory.appendingPathComponent(id.uuidString).appendingPathExtension("json")
    }
}
