# PROJECT_STATUS.md — fuente de verdad del progreso

> Leer esto (junto con [CLAUDE.md](CLAUDE.md)) antes de empezar cualquier
> sesión nueva. Ver también `git status` y `git log --oneline` para el
> estado exacto del código.

## Fase actual

**Fases 0 a 7** — **completadas**. Resumen rápido:

- **0-1**: entorno Windows listo, arquitectura e investigación.
- **2-3**: `RunCoachCore` (modelos, métricas, `RunState`, Simulation
  Engine) — 48 tests en verde en Windows.
- **4-5**: proyecto iOS + CI en Codemagic, UI SwiftUI con pantalla de
  carrera simulada.
- **6-7**: `BLEHeartRateSource` (CoreBluetooth) y `GPSLocationSource`
  (CoreLocation) — validados solo por compilación en CI, sin hardware
  real todavía.

**Fase 8** (Run Data Engine completo) — **completada** (en el sentido de
"compila"). Build de Codemagic para el commit `92a5c74` terminó `finished`
sin pasos fallidos (1m 5s). `RunSessionViewModel` ahora soporta modo real
(`.real`) además del simulado: crea `BLEHeartRateSource` +
`GPSLocationSource` con el **mismo** `Date` de referencia (resolviendo la
nota pendiente de Fase 6) y alimenta el mismo `RunState`. `RunView` deja
elegir el modo desde la pantalla inicial. El modo real sigue sin poder
probarse funcionalmente — mismo motivo que Fases 6-7 (sin hardware, sin
Mac).

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

**48 tests, 0 fallas**, en `RunCoachCore`. Sin cambios en Fase 8 — todo lo
nuevo vive en `RunCoach-iOS` (no testeable en Windows).

## Build iOS

**Fases 4 a 8 validadas en CI real** (todos los builds verdes).
Recordatorio permanente: un build verde solo confirma que compila, no que
funcione con hardware real.

### Qué se agregó en Fase 8

- `BLEHeartRateSource`/`GPSLocationSource`: `referenceStartDate` pasa de
  auto-asignarse en `start()` a ser una propiedad pública settable (con
  `Date()` como default). `isRunning` (bool interno) reemplaza el viejo
  patrón de usar `referenceStartDate != nil` como flag.
- `RunSessionViewModel`: nuevo enum `RunMode` (`.simulated`/`.real`).
  `startSimulated()` es el flujo de Fase 5 sin cambios de fondo.
  `startReal()` es nuevo: crea ambas fuentes reales, les fija un único
  `Date` de referencia compartido, y las conecta al mismo `RunState`.
  También se corrigió que `runState` no se reseteaba entre corridas
  (ahora cada `start*()` crea uno nuevo).
- `RunView`: la pantalla inicial ahora ofrece dos botones ("Simulación" /
  "Sensores reales"), con textos honestos sobre qué esperar de cada uno.
  Envuelta en `ScrollView` porque ahora tiene más contenido.

### Qué NO se hizo en Fase 8 (a propósito)

- Nada de audio/voz (Fase 9) ni Coach Decision Engine (Fase 10) — el modo
  real solo muestra métricas numéricas, igual que el simulado.
- Nada de manejo de errores hacia el usuario (sensor no encontrado, GPS
  denegado) más allá de "no se muestran datos" — se afina con datos
  reales en fases posteriores.
- Nada de autorización "Always" ni verificación de background real — Fase
  15, sin cambios respecto a Fase 7.

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
    inyectable (no auto-asignado), para que `RunSessionViewModel` pueda
    compartir un único punto de referencia temporal entre ambas fuentes.

## Arquitectura

Resumen en [docs/architecture.md](docs/architecture.md). Fase 8 completa
el patrón previsto desde el principio: `RunState` no distingue si lo
alimenta una fuente simulada o real — ambas implementan los mismos
protocolos (`HeartRateSource`/`LocationSource`) definidos en Fase 2.

## Hardware

Sin cambios respecto a Fase 1. Ver [docs/hardware.md](docs/hardware.md).
Sin compras realizadas.

## Riesgos identificados

Ver tabla completa en [docs/architecture.md](docs/architecture.md#riesgos-identificados-fase-1).
Sin cambios de fondo respecto a Fases 6-7: el modo real de
`RunSessionViewModel` hereda el mismo riesgo de "código nunca antes
corrido" de sus dos fuentes.

## Archivos creados/modificados (Fase 8)

```
RunCoach-iOS/App/BLE/BLEHeartRateSource.swift        (modificado)
RunCoach-iOS/App/GPS/GPSLocationSource.swift          (modificado)
RunCoach-iOS/App/ViewModels/RunSessionViewModel.swift (modificado)
RunCoach-iOS/App/Views/RunView.swift                  (modificado)
```

## Git

Repo en GitHub: [github.com/vinfriend/RunCoach](https://github.com/vinfriend/RunCoach),
`main` en sync con `origin/main`. Codemagic conectado.

## Próxima tarea

Esperar "Continuar con Fase 9" (Audio Coach) de Vicente — ahí entra
`AVSpeechSynthesizer` para que la app empiece a hablar, aunque todavía sin
nada inteligente que decir (eso es Fase 10, el Coach Decision Engine).
