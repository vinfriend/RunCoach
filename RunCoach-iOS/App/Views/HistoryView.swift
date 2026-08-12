import SwiftUI

/// Placeholder honesto: el historial de carreras reales (guardado,
/// análisis post-carrera) es la Fase 19. Todavía no hay nada que mostrar
/// acá.
struct HistoryView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Todavía no hay carreras guardadas")
                .font(.headline)
            Text("El historial y análisis post-carrera se implementan en la Fase 19.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .navigationTitle("Historial")
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
}
