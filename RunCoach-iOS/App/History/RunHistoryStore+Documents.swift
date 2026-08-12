import Foundation
import RunCoachCore

/// Dónde vive el historial de verdad en el iPhone. `RunHistoryStore` en sí
/// (RunCoachCore) no sabe nada de "Documents" — esa es una decisión de
/// plataforma, así que vive acá, igual que el resto de las decisiones
/// específicas de Apple en este proyecto.
extension RunHistoryStore {
    static func documentsStore() -> RunHistoryStore {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return RunHistoryStore(directory: documents.appendingPathComponent("RunHistory", isDirectory: true))
    }
}
