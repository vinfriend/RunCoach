import SwiftUI

/// La fila de OpenAI es funcional desde Fase 11 (guarda en el Keychain).
/// El resto sigue siendo placeholder honesto, apuntando a la fase que lo
/// implementa de verdad.
struct SettingsView: View {
    @State private var apiKeyInput: String = OpenAIAPIKeyStore.currentKey ?? ""
    @State private var justSaved = false

    var body: some View {
        List {
            Section("Sensor de frecuencia cardíaca") {
                Text("""
                Se conecta automáticamente al primer sensor Bluetooth \
                que exponga el Heart Rate Service estándar — sin \
                selección manual todavía.
                """)
                    .foregroundStyle(.secondary)
            }

            Section {
                SecureField("sk-...", text: $apiKeyInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Guardar") {
                    OpenAIAPIKeyStore.save(apiKeyInput)
                    justSaved = true
                }
                .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if justSaved {
                    Text("Guardada en el Keychain de este iPhone.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("API key de OpenAI")
            } footer: {
                Text("""
                Se guarda únicamente en el Keychain de este dispositivo — \
                nunca en el código ni en Git. Sin una key configurada, el \
                coach sigue funcionando con frases fijas en español.
                """)
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
