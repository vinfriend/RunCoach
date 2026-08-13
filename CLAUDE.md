# CLAUDE.md — Guía para sesiones de Claude Code en este repo

Este archivo orienta a cualquier sesión de Claude Code (o a Vicente) que retome
este proyecto. Léelo junto con [PROJECT_STATUS.md](PROJECT_STATUS.md) **antes**
de tocar código.

## Qué es este proyecto

RunCoach: app iOS de coaching de running en tiempo real. Pulsera/sensor BLE
(sin pantalla) para frecuencia cardíaca + iPhone para GPS/tiempo/ritmo +
AirPods para audio. Procesamiento local de métricas, decisión prudente de
cuándo hablar, y consulta a OpenAI solo para eventos relevantes. No es
software médico: no diagnostica, solo hace coaching deportivo.

## Antes de empezar cualquier sesión

1. Leer este archivo completo.
2. Leer [PROJECT_STATUS.md](PROJECT_STATUS.md) — fuente de verdad del progreso.
3. Ejecutar `git status` y revisar el historial reciente (`git log --oneline -20`).
4. No rehacer trabajo ya terminado. Si algo en PROJECT_STATUS.md parece
   desactualizado respecto al código real, el código manda — corregir el doc.

## Entorno de trabajo

- **Vicente no es desarrollador profesional.** No le pidas que pegue código,
  edite archivos a mano o ejecute comandos si vos podés hacerlo directamente
  con tus herramientas. Ejecutá vos, mostrale el resultado.
- **Windows, sin Mac.** Todo el desarrollo diario ocurre en Windows (AMD Ryzen
  AI 7, 16 hilos, ~14GB RAM). El build de Xcode/iOS ocurre en macOS remoto vía
  Codemagic — ver [docs/ios-build.md](docs/ios-build.md).
- **RunCoachCore** (Swift Package puro, sin dependencias de Apple frameworks
  más allá de Foundation) se compila y testea localmente en Windows con
  `swift build` / `swift test`. Es la fuente de verdad de la lógica de
  dominio.
- **RunCoach-iOS** depende de SwiftUI/CoreBluetooth/CoreLocation/AVFoundation
  y solo puede compilarse en macOS — se valida vía CI en Codemagic.
- El proyecto Xcode se genera declarativamente (XcodeGen, `project.yml`) en
  vez de versionar `.xcodeproj` a mano. Ver [docs/ios-build.md](docs/ios-build.md).

## Reglas de interacción (heredadas del prompt maestro de Vicente)

- Trabajar con autonomía en tareas locales, reversibles y técnicas: crear/
  editar código, tests, dependencias de desarrollo razonables, commits,
  documentación, investigación, corrección de errores.
- Detenerse y pedir una **ACCIÓN NECESARIA DE VICENTE** explícita solo para lo
  que Claude no puede hacer: contraseñas, login, OAuth, ventanas de seguridad
  de Windows, pagos, tarjetas, términos legales, Apple Developer, pruebas
  físicas con iPhone/pulsera.
- Nunca operaciones destructivas de Git (`reset --hard`, force push, borrado
  masivo) sin aprobación explícita.
- Nunca compras, suscripciones, pagos, o creación de claves de servicios
  pagos (OpenAI, Apple Developer) sin aprobación explícita.
- No declarar una fase completa si no se cumplen sus criterios de aceptación.
- Ciclo por cambio: implementar → compilar/validar → test → corregir →
  documentar → commit.

## Estructura del repo

```
RunCoachCore/       Swift Package portable — modelos, métricas, motor de
                     carrera, Coach Decision Engine, simulación, tests.
                     Se prueba en Windows.
RunCoach-iOS/        Proyecto iOS (SwiftUI, CoreBluetooth, CoreLocation,
                     AVFoundation). Se compila solo en macOS/CI.
docs/                Documentación técnica detallada por tema.
.github/workflows/   CI (lint/test de RunCoachCore en cada push, cuando se
                     configure GitHub).
```

## Roadmap

Ver PROJECT_STATUS.md para el estado fase por fase. El roadmap completo (20
fases) vive en el prompt original de Vicente y se resume en
[docs/architecture.md](docs/architecture.md).

## Requisitos permanentes de producto

Decisiones que valen para todo el proyecto de acá en adelante, no solo para
la fase en la que se originaron. Cualquier trabajo futuro de audio debe
respetar esto sin que haga falta repetirlo:

- **El Audio Coach nunca se apropia de la sesión de audio de forma
  permanente.** Durante una carrera, el usuario debe poder escuchar música
  de Spotify/YouTube Music/Apple Music/cualquier app compatible con iOS con
  normalidad. RunCoach solo baja el volumen de esa música (ducking) mientras
  efectivamente está hablando, y se lo devuelve a la normalidad apenas
  termina — mismo patrón que una app de navegación GPS. Nunca pausa/
  reanuda otras apps directamente, nunca depende de un SDK específico de
  proveedor (Spotify, Apple Music, etc.). Implementado en
  `AudioCoachService` (`RunCoach-iOS/App/Audio/`) — ver
  [docs/audio-coach.md](docs/audio-coach.md) para el diseño completo y
  [docs/decisions.md](docs/decisions.md) para el porqué de cada elección de
  `AVAudioSession`.

## Secretos

Nunca commitear API keys (OpenAI, Apple, etc.). Usar `.gitignore` existente
(`Secrets.swift`, `Config.local.*`, `.env`). Si una clave se necesita en CI,
va como variable de entorno segura en Codemagic, nunca en el repo.
