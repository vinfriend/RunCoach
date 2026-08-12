# PROJECT_STATUS.md — fuente de verdad del progreso

> Leer esto (junto con [CLAUDE.md](CLAUDE.md)) antes de empezar cualquier
> sesión nueva. Ver también `git status` y `git log --oneline` para el
> estado exacto del código.

## Fase actual

**Fase 0** (entorno Windows) — **completada**.
**Fase 1** (arquitectura/investigación) — **completada**.
**Fase 2** (RunCoachCore: modelos, métricas, `RunState`) — **completada**.
**Fase 3** (Simulation Engine) — **completada**.
**Fase 4** (Proyecto iOS + CI macOS) — **completada**.
**Fase 5** (UI SwiftUI) — **completada**. Build de Codemagic para el commit
`58b7a87` terminó `finished` sin pasos fallidos (1m 22s) — confirma que
compila. **Nota importante**: "compila en CI" no es lo mismo que "se ve o
funciona bien" — nunca se corrió en un simulador/iPhone real (no hay Mac).
Eso queda pendiente de las Fases 12-13.

Nota de proceso: el trigger automático por `push` de Codemagic no disparó
build para los últimos commits — hubo que iniciarlos a mano desde el
dashboard ("Start new build"). Puede ser una configuración de webhook a
revisar más adelante si se vuelve molesto; por ahora no bloquea nada.

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

Sin cambios respecto a Fase 3: **40 tests, 0 fallas**, en `RunCoachCore`.
Fase 4 y Fase 5 no agregaron lógica a `RunCoachCore` — todo lo nuevo vive
en `RunCoach-iOS`, que no se puede testear en Windows (ver
[docs/windows-development.md](docs/windows-development.md)).

## Build iOS

**Fase 4 y Fase 5 validadas en CI real** (ambos builds verdes). Recordar
siempre: un build verde en Codemagic **solo confirma que compila** — no
que la UI se vea bien, que la navegación funcione, o que el timing de la
simulación sea razonable. Eso requiere correrlo en un simulador o iPhone
real, que todavía no tenemos (Fases 12-13).

### Qué se agregó en Fase 5

- `RunCoach-iOS/App/ViewModels/RunSessionViewModel.swift`: `ObservableObject`
  que envuelve `RunState` + `ScenarioSimulator` de `RunCoachCore` (Fase 3)
  con pacing en tiempo real acelerado (20x por defecto, usando
  `DispatchQueue.main.asyncAfter`) — el escenario de 20 minutos se ve en
  ~1 minuto. Este pacing vive acá (no en `RunCoachCore`) porque usa
  `DispatchQueue`, que no existe en Windows/Linux.
- `RunCoach-iOS/App/Views/RunView.swift`: pantalla de carrera. Estado
  inicial con botón "Iniciar carrera (simulación)" y aviso explícito de
  que no hay sensores reales todavía; estado corriendo con tiempo
  transcurrido, distancia, ritmo, FC + ícono de tendencia, y lista de
  splits a medida que se completan.
- `RunCoach-iOS/App/Views/HistoryView.swift` y `SettingsView.swift`:
  placeholders honestos, cada uno indicando en qué fase futura se
  implementa de verdad (Fase 19 y Fase 6/11 respectivamente).
- `RunCoach-iOS/App/ContentView.swift`: reemplaza el placeholder de Fase 4
  por un `TabView` real (Correr / Historial / Ajustes).

### Qué NO se hizo en Fase 5 (a propósito)

- Nada de BLE (Fase 6) ni GPS real (Fase 7) — la pantalla de carrera solo
  consume el escenario simulado.
- Nada de audio/voz (Fase 9) ni Coach Decision Engine (Fase 10) — no hay
  ninguna recomendación hablada todavía, solo métricas numéricas en
  pantalla.
- Nada de persistencia — el historial es un placeholder vacío.

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
11. `info.path` es obligatorio en el bloque `info:` de XcodeGen (bug real
    encontrado y corregido en el primer build de Fase 4).
12. Pacing en tiempo real de la simulación vive en `RunCoach-iOS`
    (`RunSessionViewModel`), no en `RunCoachCore` — usa `DispatchQueue`,
    rompería la portabilidad a Windows si estuviera en el core.

## Arquitectura

Resumen en [docs/architecture.md](docs/architecture.md). Fase 5 no cambió
el diseño de fondo — agregó la capa de presentación (SwiftUI) sobre
`RunCoachCore`, consumiendo el Simulation Engine de Fase 3 tal como estaba
previsto ("el mismo motor consume fuentes simuladas y reales").

## Hardware

Sin cambios respecto a Fase 1. Ver [docs/hardware.md](docs/hardware.md).
Sin compras realizadas.

## Riesgos identificados

Ver tabla completa en [docs/architecture.md](docs/architecture.md#riesgos-identificados-fase-1).
Nuevo en Fase 5: el código de `RunCoach-iOS` (SwiftUI) nunca se compiló ni
se vio corriendo antes de este commit — ni siquiera hay certeza de que el
build de CI ya haya corrido. Es el mismo riesgo estructural de no tener Mac
local, ahora aplicado a código de UI en vez de solo configuración.

## Archivos creados (nuevos en Fase 5)

```
RunCoach-iOS/App/ViewModels/RunSessionViewModel.swift
RunCoach-iOS/App/Views/RunView.swift
RunCoach-iOS/App/Views/HistoryView.swift
RunCoach-iOS/App/Views/SettingsView.swift
```

(`RunCoach-iOS/App/ContentView.swift` se modificó, no es nuevo.)

## Git

Repo en GitHub: [github.com/vinfriend/RunCoach](https://github.com/vinfriend/RunCoach),
`main` en sync con `origin/main`. Codemagic conectado.

## Próxima tarea

Esperar confirmación explícita de Vicente ("Continuar con Fase 6") antes de
empezar BLE real (`BLEHeartRateSource` con CoreBluetooth, contra el
Heart Rate Service estándar 0x180D investigado en Fase 1). Recordar que
sigue sin poder probarse con hardware real hasta las Fases 12-14.
