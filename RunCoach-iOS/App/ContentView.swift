import SwiftUI
import RunCoachCore

/// Pantalla placeholder de la Fase 4: solo existe para probar que el
/// target de la app compila e integra `RunCoachCore` de punta a punta en
/// CI (Codemagic). La UI real de la carrera es la Fase 5.
struct ContentView: View {
    private let runState = RunState()

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.run")
                .font(.system(size: 48))
            Text("RunCoach")
                .font(.title)
                .bold()
            Text("RunCoachCore conectado (distancia inicial: \(Int(runState.totalDistanceMeters)) m)")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
