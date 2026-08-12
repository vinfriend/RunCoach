import SwiftUI

/// Placeholder honesto: nada de esto es configurable todavía. Cada fila
/// apunta a la fase que lo implementa de verdad.
struct SettingsView: View {
    var body: some View {
        List {
            Section("Sensor de frecuencia cardíaca") {
                Text("Sin configurar — la conexión BLE real llega en la Fase 6.")
                    .foregroundStyle(.secondary)
            }
            Section("OpenAI") {
                Text("Sin configurar — la integración con OpenAI llega en la Fase 11.")
                    .foregroundStyle(.secondary)
            }
            Section("Acerca de") {
                LabeledContent("RunCoach", value: "0.1.0")
            }
        }
        .navigationTitle("Ajustes")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
