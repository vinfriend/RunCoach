import SwiftUI
import RunCoachCore

/// Detalle de una carrera guardada: todas las métricas y todos los
/// splits, no solo el resumen que muestra la fila de `HistoryView`.
struct RunDetailView: View {
    let run: CompletedRun

    var body: some View {
        List {
            Section("Resumen") {
                LabeledContent("Fecha") {
                    Text(run.startedAt, style: .date)
                }
                LabeledContent("Hora") {
                    Text(run.startedAt, style: .time)
                }
                LabeledContent("Modo", value: run.mode == "simulated" ? "Simulación" : "Real")
                LabeledContent("Duración", value: RunFormatting.duration(run.durationSeconds))
                LabeledContent("Distancia", value: RunFormatting.distance(run.totalDistanceMeters))
                if let averageHeartRateBPM = run.averageHeartRateBPM {
                    LabeledContent("FC promedio", value: "\(Int(averageHeartRateBPM.rounded())) bpm")
                }
                if let averagePace = averagePaceSecondsPerKm {
                    LabeledContent("Ritmo promedio", value: RunFormatting.pace(averagePace))
                }
            }

            if !run.splits.isEmpty {
                Section("Splits") {
                    ForEach(run.splits, id: \.index) { split in
                        HStack {
                            Text("Km \(split.index + 1)")
                            Spacer()
                            Text(RunFormatting.pace(split.averagePaceSecondsPerKm))
                            if let averageHeartRateBPM = split.averageHeartRateBPM {
                                Text("·")
                                Text("\(Int(averageHeartRateBPM.rounded())) bpm")
                            }
                        }
                        .font(.footnote)
                    }
                }
            }
        }
        .navigationTitle("Detalle de carrera")
    }

    /// Ritmo promedio de toda la carrera, derivado de duración/distancia
    /// totales — no hay un campo separado para esto en `CompletedRun`,
    /// se calcula acá porque es puramente de presentación.
    private var averagePaceSecondsPerKm: Double? {
        guard run.totalDistanceMeters > 0 else { return nil }
        return run.durationSeconds / (run.totalDistanceMeters / 1000)
    }
}

#Preview {
    NavigationStack {
        RunDetailView(run: CompletedRun(
            startedAt: Date(),
            durationSeconds: 1500,
            totalDistanceMeters: 5000,
            averageHeartRateBPM: 152,
            splits: [
                Split(index: 0, distanceMeters: 1000, durationSeconds: 300, averageHeartRateBPM: 145),
                Split(index: 1, distanceMeters: 1000, durationSeconds: 295, averageHeartRateBPM: 150),
                Split(index: 2, distanceMeters: 1000, durationSeconds: 310, averageHeartRateBPM: 158)
            ],
            mode: "simulated"
        ))
    }
}
