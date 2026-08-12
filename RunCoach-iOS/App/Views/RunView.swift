import SwiftUI
import RunCoachCore

/// Pantalla principal de carrera. Sin sensores reales todavía (Fases 6-7):
/// el botón "Iniciar" corre el escenario de referencia simulado de
/// RunCoachCore (Fase 3) a velocidad acelerada, para poder probar la UI y
/// el motor de métricas de punta a punta sin hardware.
struct RunView: View {
    @StateObject private var session = RunSessionViewModel()

    var body: some View {
        Group {
            if session.isRunning {
                metricsView
            } else {
                startView
            }
        }
        .padding()
        .navigationTitle("Correr")
    }

    private var startView: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Sin sensores reales todavía")
                .font(.headline)
            Text("""
            Esta pantalla corre el escenario de referencia simulado de 20 \
            minutos, acelerado, para poder probar la app sin hardware. La \
            conexión a un sensor de FC real y al GPS llegan en fases \
            siguientes.
            """)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Iniciar carrera (simulación)") {
                session.start()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var metricsView: some View {
        VStack(spacing: 20) {
            Text(formattedElapsed)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()

            HStack(spacing: 32) {
                metricTile(title: "Distancia", value: formattedDistance)
                metricTile(title: "Ritmo", value: formattedPace(session.currentPaceSecondsPerKm))
            }

            HStack(spacing: 8) {
                Image(systemName: heartRateTrendIcon)
                Text(formattedHeartRate)
                    .font(.title2)
                    .monospacedDigit()
            }
            .foregroundStyle(heartRateTrendColor)

            if !session.splits.isEmpty {
                splitsList
            }

            Spacer()

            Button("Detener", role: .destructive) {
                session.stop()
            }
        }
    }

    private var splitsList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Splits")
                .font(.headline)
            ForEach(session.splits, id: \.index) { split in
                HStack {
                    Text("Km \(split.index + 1)")
                    Spacer()
                    Text(formattedPace(split.averagePaceSecondsPerKm))
                }
                .font(.footnote)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricTile(title: String, value: String) -> some View {
        VStack {
            Text(value)
                .font(.title2)
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var formattedElapsed: String {
        let totalSeconds = Int(session.elapsedSeconds)
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private var formattedDistance: String {
        String(format: "%.2f km", session.totalDistanceMeters / 1000)
    }

    private func formattedPace(_ secondsPerKm: Double?) -> String {
        guard let secondsPerKm, secondsPerKm.isFinite else { return "—" }
        let totalSeconds = Int(secondsPerKm)
        return String(format: "%d:%02d /km", totalSeconds / 60, totalSeconds % 60)
    }

    private var formattedHeartRate: String {
        guard let bpm = session.smoothedHeartRateBPM else { return "— bpm" }
        return "\(Int(bpm.rounded())) bpm"
    }

    private var heartRateTrendIcon: String {
        switch session.heartRateTrend {
        case .rising: return "arrow.up.right"
        case .falling: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }

    private var heartRateTrendColor: Color {
        switch session.heartRateTrend {
        case .rising: return .orange
        case .falling: return .blue
        case .stable: return .primary
        }
    }
}

#Preview {
    NavigationStack {
        RunView()
    }
}
