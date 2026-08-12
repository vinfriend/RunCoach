import SwiftUI
import RunCoachCore

/// Pantalla principal de carrera. Dos modos (Fase 8):
///
/// - **Simulación**: corre el escenario de referencia de RunCoachCore
///   (Fase 3) a velocidad acelerada. Validado end-to-end desde Fase 5.
/// - **Real**: usa `BLEHeartRateSource` (Fase 6) y `GPSLocationSource`
///   (Fase 7) de verdad. Sin sensor ni GPS conectados, este modo
///   simplemente no va a mostrar datos — no hay forma de probarlo sin
///   hardware real (Fase 14) ni de verlo funcionar en el simulador de iOS
///   (sin radio Bluetooth ahí). Está acá porque el "motor" ya está
///   completo (Fase 8), no porque ya se haya usado con éxito.
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
        ScrollView {
            startViewContent
        }
    }

    private var startViewContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("Simulación")
                .font(.headline)
            Text("""
            Corre el escenario de referencia simulado de 20 minutos, \
            acelerado, para probar la app sin hardware.
            """)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Iniciar carrera (simulación)") {
                session.startSimulated()
            }
            .buttonStyle(.borderedProminent)

            Divider()
                .padding(.vertical, 4)

            Text("Sensores reales")
                .font(.headline)
            Text("""
            Usa un sensor de FC por Bluetooth y el GPS del iPhone de \
            verdad. Sin un sensor conectado no va a mostrar datos — \
            todavía no se probó con hardware real.
            """)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Iniciar carrera (sensores reales)") {
                session.startReal()
            }
            .buttonStyle(.bordered)
        }
    }

    private var metricsView: some View {
        VStack(spacing: 20) {
            if let mode = session.mode {
                Text(mode == .simulated ? "Simulación" : "Sensores reales")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }

            Text(RunFormatting.duration(session.elapsedSeconds))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()

            HStack(spacing: 32) {
                metricTile(title: "Distancia", value: RunFormatting.distance(session.totalDistanceMeters))
                metricTile(title: "Ritmo", value: RunFormatting.pace(session.currentPaceSecondsPerKm, whenMissing: "—"))
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
                    Text(RunFormatting.pace(split.averagePaceSecondsPerKm, whenMissing: "—"))
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
