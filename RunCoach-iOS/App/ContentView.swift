import SwiftUI

/// Shell de navegación principal: tres pestañas (Correr / Historial /
/// Ajustes). El placeholder de Fase 4 (probar que RunCoachCore se integra
/// en el target) queda superado por `RunView`, que ya usa RunCoachCore de
/// verdad para algo con sentido.
struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                RunView()
            }
            .tabItem {
                Label("Correr", systemImage: "figure.run")
            }

            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("Historial", systemImage: "clock.arrow.circlepath")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Ajustes", systemImage: "gearshape")
            }
        }
    }
}

#Preview {
    ContentView()
}
