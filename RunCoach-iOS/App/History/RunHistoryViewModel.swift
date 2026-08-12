import Foundation
import RunCoachCore

/// Carga y expone las carreras guardadas (Fase 19) para `HistoryView`.
final class RunHistoryViewModel: ObservableObject {
    @Published private(set) var runs: [CompletedRun] = []

    private let store: RunHistoryStore

    init(store: RunHistoryStore = .documentsStore()) {
        self.store = store
        reload()
    }

    func reload() {
        runs = store.loadAll()
    }

    func delete(_ run: CompletedRun) {
        try? store.delete(run)
        reload()
    }
}
