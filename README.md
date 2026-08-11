# RunCoach

Coach inteligente de running en tiempo real para iPhone + AirPods + pulsera
BLE de frecuencia cardíaca (sin pantalla, sin Apple Watch).

> Proyecto personal de Vicente. No es software médico: no diagnostica, solo
> ofrece coaching deportivo prudente.

## Cómo funciona (visión general)

```
Pulsera BLE (HR) ─┐
                   ├─► iPhone (GPS, tiempo, ritmo) ─► RunCoachCore
                   │      (procesa localmente, decide si algo es
                   │       relevante, consulta OpenAI solo si hace falta)
                   └────────────────────────────────► AirPods (voz)
```

Detalle completo en [docs/architecture.md](docs/architecture.md).

## Estructura del repo

- [`RunCoachCore/`](RunCoachCore/) — Swift Package portable (modelos,
  métricas, motor de carrera, Coach Decision Engine, simulación). Se
  compila y testea en Windows con `swift build` / `swift test`.
- [`RunCoach-iOS/`](RunCoach-iOS/) — app iOS (SwiftUI, CoreBluetooth,
  CoreLocation, AVFoundation). Se compila solo en macOS, vía CI remoto.
- [`docs/`](docs/) — documentación técnica detallada.

## Documentación

- [CLAUDE.md](CLAUDE.md) — guía para retomar el proyecto (leer primero).
- [PROJECT_STATUS.md](PROJECT_STATUS.md) — estado real del proyecto, fuente
  de verdad del progreso.
- [docs/architecture.md](docs/architecture.md) — arquitectura y módulos.
- [docs/decisions.md](docs/decisions.md) — decisiones técnicas y por qué.
- [docs/windows-development.md](docs/windows-development.md) — desarrollo
  desde Windows sin Mac.
- [docs/ios-build.md](docs/ios-build.md) — build de iOS sin Mac local
  (Codemagic, XcodeGen).
- [docs/testing.md](docs/testing.md) — estrategia de testing y Simulation
  Mode.
- [docs/hardware.md](docs/hardware.md) — investigación de sensores BLE de
  frecuencia cardíaca.
- [docs/openai.md](docs/openai.md) — integración con OpenAI (fase futura).
- [docs/real-world-tests.md](docs/real-world-tests.md) — registro de
  pruebas con hardware real (fase futura).

## Estado

Ver [PROJECT_STATUS.md](PROJECT_STATUS.md). Al momento de este commit: Fase
0 (entorno) y Fase 1 (arquitectura/investigación) en curso.
