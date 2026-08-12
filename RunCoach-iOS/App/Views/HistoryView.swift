import SwiftUI
import RunCoachCore

/// Lista real de carreras guardadas (Fase 19) — reemplaza el placeholder
/// de Fase 5. Cada carrera (simulada o real, Fases 5-8) que termina queda
/// acá, gracias a `RunSessionViewModel.finishRun()`.
struct HistoryView: View {
    @StateObject private var viewModel = RunHistoryViewModel()

    var body: some View {
        Group {
            if viewModel.runs.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle("Historial")
        .onAppear { viewModel.reload() }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Todavía no hay carreras guardadas")
                .font(.headline)
            Text("Terminá una carrera (simulada o real) en la pestaña Correr para que aparezca acá.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }

    private var list: some View {
        List {
            ForEach(viewModel.runs) { run in
                NavigationLink(destination: RunDetailView(run: run)) {
                    runRow(run)
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    viewModel.delete(viewModel.runs[index])
                }
            }
        }
    }

    private func runRow(_ run: CompletedRun) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(run.startedAt, style: .date)
                Text(run.startedAt, style: .time)
                Spacer()
                Text(run.mode == "simulated" ? "Simulación" : "Real")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Text(RunFormatting.duration(run.durationSeconds))
                Text("·")
                Text(RunFormatting.distance(run.totalDistanceMeters))
                if let averageHeartRateBPM = run.averageHeartRateBPM {
                    Text("·")
                    Text("\(Int(averageHeartRateBPM.rounded())) bpm prom.")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            if !run.splits.isEmpty {
                Text("\(run.splits.count) split\(run.splits.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
}
