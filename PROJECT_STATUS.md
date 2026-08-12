# PROJECT_STATUS.md — fuente de verdad del progreso

> Leer esto (junto con [CLAUDE.md](CLAUDE.md)) antes de empezar cualquier
> sesión nueva. Ver también `git status` y `git log --oneline` para el
> estado exacto del código.

## Fase actual

**Fases 0 a 8** — **completadas**. Resumen rápido:

- **0-1**: entorno Windows listo, arquitectura e investigación.
- **2-3**: `RunCoachCore` (modelos, métricas, `RunState`, Simulation
  Engine) — 48 tests en verde en Windows.
- **4-5**: proyecto iOS + CI en Codemagic, UI SwiftUI con pantalla de
  carrera simulada.
- **6-7**: `BLEHeartRateSource` (CoreBluetooth) y `GPSLocationSource`
  (CoreLocation) — validados solo por compilación en CI, sin hardware
  real todavía.
- **8**: `RunSessionViewModel` soporta modo real (BLE+GPS con `Date` de
  referencia compartido) además del simulado; `RunView` deja elegir.

**Fase 9** (Audio Coach) — **completada** (en el sentido de "compila").
Build de Codemagic para el commit `4477ba1` terminó `finished` sin pasos
fallidos (1m 5s). `AudioCoach` (`AVSpeechSynthesizer`, voz `es-AR`) es
pura infraestructura de voz — sin ninguna lógica de decisión. Anuncia
eventos mecánicos que `RunCoachCore` ya calcula: inicio/fin de carrera,
cada split completado con su ritmo. El Coach Decision Engine (cuándo/qué
vale la pena decir) sigue siendo Fase 10, no implementado.

Nota de proceso (desde Fase 5): el trigger automático por `push` de
Codemagic no dispara solo — hay que iniciar el build a mano desde el
dashboard ("Start new build") cada vez.

## Último commit estable

Ver `git log --oneline -1` para el hash exacto.

## Bloqueos

Ninguno activo.

## Entorno Windows

| Item | Estado |
|---|---|
| Windows 11 Home 10.0.26200, x64 | OK |
| AMD Ryzen AI 7 350, 8 núcleos/16 hilos, ~14GB RAM, ~334GB libres en C:\ | OK |
| Git 2.54.0 | OK, ya configurado |
| Swift toolchain 6.3.3 (swift.org, winget) | OK |
| Visual Studio 2022 Build Tools + Windows 11 SDK (10.0.22621.0) | OK |
| VS Code 1.118.0 | OK |
| winget 1.29.280 | OK |
| GitHub CLI (`gh`) | Instalado, sin autenticar (no hizo falta — push por HTTPS) |
| Docker | No instalado — no requerido por ahora |

Detalle completo en [docs/windows-development.md](docs/windows-development.md).

## Tests en Windows

**48 tests, 0 fallas**, en `RunCoachCore`. Sin cambios desde Fase 3 — todo
lo de Fases 4-9 vive en `RunCoach-iOS` (no testeable en Windows).

## Build iOS

**Fases 4 a 9 validadas en CI real** (todos los builds verdes).
Recordatorio permanente: un build verde solo confirma que compila, no que
funcione (ni siquiera que se escuche) con hardware real.

### Qué se agregó en Fase 9

- `RunCoach-iOS/App/Audio/AudioCoach.swift`: envuelve
  `AVSpeechSynthesizer` con voz `es-AR`, `AVAudioSession` en
  `.playback`/`.spokenAudio`/`.duckOthers` (suena con el iPhone en
  silencio, baja otro audio en vez de cortarlo). Método único relevante:
  `speak(_ text: String)` — no decide nada, solo dice lo que le pasan.
- `RunSessionViewModel`: ahora anuncia por voz el inicio de carrera
  (simulada o real), el fin de la carrera simulada, la detención manual, y
  cada split completado con su ritmo (ej. "Kilómetro 2. Ritmo: 5 minutos
  30 por kilómetro.").

### Qué NO se hizo en Fase 9 (a propósito)

- **Nada de lógica de decisión** — sin prioridades, cooldown,
  deduplicación, ni juicio sobre si vale la pena hablar. Eso es
  explícitamente el Coach Decision Engine, Fase 10.
- Sin manejo de interrupciones de audio (llamadas telefónicas, otra app
  tomando la sesión) — se afina con un iPhone real (Fase 13+).
- Sin voz conversacional ni Realtime API — el prompt original es
  explícito: "no introducir voz conversacional completa... primero quiero
  que el coach me hable, no necesito hablarle durante una carrera."

## Decisiones tomadas

Ver [docs/decisions.md](docs/decisions.md) para el detalle y motivos:

1. Swift toolchain oficial de swift.org para Windows (no WSL2).
2. Visual Studio 2022 Build Tools + Windows 11 SDK, con
   `scripts/setup-swift-env.ps1` para cargar el entorno en cada terminal.
3. Codemagic como CI macOS remoto (free tier 500 min/mes).
4. XcodeGen para generar el proyecto Xcode de forma declarativa.
5. WHOOP validado como fuente HR viable (con matiz); Polar Verity Sense /
   Scosche Rhythm24 como plan B.
6. `HeartRateSource`/`LocationSource` con closures, no Combine.
7. Timestamps como `TimeInterval` relativo, no `Date`.
8. Simulation Engine con reproducción síncrona e inmediata en los Mock
   sources.
9. Bundle ID `com.vicente.runcoach` como placeholder hasta Fase 12.
10. Primer build de CI sin firma (solo simulador).
11. `info.path` es obligatorio en el bloque `info:` de XcodeGen.
12. Pacing en tiempo real de la simulación vive en `RunCoach-iOS`, no en
    `RunCoachCore`.
13. Parsing GATT del Heart Rate Service vive en `RunCoachCore` (portable,
    testeable en Windows); CoreBluetooth vive en `RunCoach-iOS`.
14. `GPSLocationSource` solo pide autorización "When In Use" — "Always" y
    la validación de background real quedan para Fase 15.
15. `referenceStartDate` de `BLEHeartRateSource`/`GPSLocationSource` es
    inyectable (no auto-asignado), compartido entre ambas fuentes.
16. `AudioCoach` es infraestructura pura, sin lógica de decisión — los
    anuncios de Fase 9 están atados a eventos mecánicos de RunCoachCore,
    no a juicios sobre qué vale la pena decir (eso es Fase 10).

## Arquitectura

Resumen en [docs/architecture.md](docs/architecture.md). Con Fase 9, las
tres piezas del lado Apple (BLE, GPS, Audio) ya existen; falta la que las
conecta con inteligencia real (Coach Decision Engine, Fase 10) y la que
las conecta con IA externa (OpenAI, Fase 11).

## Hardware

Sin cambios respecto a Fase 1. Ver [docs/hardware.md](docs/hardware.md).
Sin compras realizadas.

## Riesgos identificados

Ver tabla completa en [docs/architecture.md](docs/architecture.md#riesgos-identificados-fase-1).
`AudioCoach` es, a diferencia de BLE, algo que en teoría el simulador de
iOS podría reproducir (tiene salida de audio) — pero sin Mac para abrir
Xcode, el riesgo práctico de "código nunca antes escuchado" es el mismo
que en Fases 6-8.

## Archivos creados/modificados (Fase 9)

```
RunCoach-iOS/App/Audio/AudioCoach.swift               (nuevo)
RunCoach-iOS/App/ViewModels/RunSessionViewModel.swift (modificado)
```

## Git

Repo en GitHub: [github.com/vinfriend/RunCoach](https://github.com/vinfriend/RunCoach),
`main` en sync con `origin/main`. Codemagic conectado.

## Próxima tarea

Esperar "Continuar con Fase 10" (Coach Decision Engine) de Vicente — la
pieza central del proyecto: prioridades, cooldown, deduplicación, y la
decisión de hablar o quedarse callado. Esta sí se puede testear de verdad
en Windows (es lógica pura, va en RunCoachCore), a diferencia de las
últimas cuatro fases.
