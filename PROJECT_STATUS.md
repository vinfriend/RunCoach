# PROJECT_STATUS.md — fuente de verdad del progreso

> Leer esto (junto con [CLAUDE.md](CLAUDE.md)) antes de empezar cualquier
> sesión nueva. Ver también `git status` y `git log --oneline` para el
> estado exacto del código.

## Fase actual

**Fases 0 a 11** — **completadas**. Resumen rápido:

- **0-1**: entorno Windows listo, arquitectura e investigación.
- **2-3**: `RunCoachCore` (modelos, métricas, `RunState`, Simulation
  Engine).
- **4-5**: proyecto iOS + CI en Codemagic, UI SwiftUI con carrera simulada.
- **6-7**: `BLEHeartRateSource`/`GPSLocationSource` — solo compilación en
  CI. `HeartRateMeasurementParser` testeado en Windows.
- **8**: modo real (BLE+GPS con `Date` de referencia compartido) conectado
  a la UI.
- **9**: `AudioCoach` (voz `es-AR`) anuncia eventos mecánicos.
- **10**: `CoachDecisionEngine` — la pieza central, decide cuándo hablar.
- **11**: integración con OpenAI (armado/parseo portable, cliente real
  con timeout/retry). Sin API key configurada todavía.

**Fase 12** (Apple Developer / firma) — **bloqueada indefinidamente por
decisión de Vicente**: no quiere pagar la membresía todavía. Fases 13-18
(TestFlight, sensor físico, GPS/background real, integración con
hardware, prueba real, correcciones) dependen todas de Fase 12 — quedan
bloqueadas también. Ver [docs/ios-build.md](docs/ios-build.md#fase-12--apple-developer--firma)
para el plan completo, listo para retomar cuando Vicente decida.

**Fase 19** (Historial y análisis post-carrera) — **adelantada y
completada**. Build de Codemagic para el commit `f4e6457` terminó
`finished` sin pasos fallidos (1m 18s). No depende de firma ni de
hardware, así que se adelantó salteando 12-18 por instrucción explícita
de Vicente ("continuá todo lo que sea posible sin la membresía"). Ver
docs/decisions.md para el razonamiento completo de por qué el roadmap deja
de ser estrictamente secuencial acá.

- `CompletedRun`/`RunHistoryStore` (RunCoachCore): persistencia real a
  disco vía `FileManager` — **83 tests en total, 10 nuevos**, incluyendo
  E/S real con directorios temporales en Windows. (El trabajo posterior a
  Fase 19 sumó 10 tests más, llegando a los 93 actuales — ver más abajo.)
- `HistoryView` ya no es un placeholder: lista real, con borrado, de
  carreras guardadas.
- Cada carrera (simulada o real) que termina se guarda automáticamente.

Nota de proceso (desde Fase 5): el trigger automático por `push` de
Codemagic no dispara solo — hay que iniciar el build a mano desde el
dashboard ("Start new build") cada vez.

**Post-Fase 19 (sin número de fase — trabajo pedido dentro de lo
alcanzable sin cuenta de Apple ni hardware)** — **completado**. Vicente
eligió las tres líneas de trabajo ofrecidas: Coach Decision Engine más
completo, vista de detalle de carrera, y revisión de calidad/refactor sin
funcionalidad nueva. Ver docs/decisions.md para el detalle de diseño de
cada una.

- `PaceTrend` (RunCoachCore) + `CoachEvent.deteriorating` (FC subiendo y
  ritmo empeorando a la vez) — primer caso real de arbitraje de prioridad
  entre eventos candidatos, resuelto en `CoachEventDetector`. **93 tests
  en total, 10 nuevos** (verificado con `swift test`).
- `RunDetailView` (RunCoach-iOS): pantalla de detalle de una carrera
  guardada, accesible desde `HistoryView`.
- `RunFormatting` (RunCoach-iOS): formateo de duración/distancia/ritmo
  centralizado — corrige una inconsistencia real encontrada en la
  revisión (`RunView` truncaba el ritmo, `RunDetailView` lo redondeaba).
- Revisión de calidad sobre todo `RunCoachCore`/`RunCoach-iOS`: sin
  TODO/FIXME pendientes, `MovingAverage` ahora `Sendable` (consistencia
  con el resto del módulo), force-unwraps existentes revisados y
  confirmados seguros (`CBCentralManager!` idiomático,
  `URL(string:)!` sobre literal constante).

## Último commit estable

Ver `git log --oneline -1` para el hash exacto.

## Bloqueos

- **Fases 12-18 bloqueadas por decisión de Vicente** (no técnica): no
  quiere pagar la membresía de Apple Developer Program todavía. No es
  algo que yo deba insistir en resolver — el plan queda documentado y
  listo para cuando él decida. Ver
  [docs/ios-build.md](docs/ios-build.md#fase-12--apple-developer--firma).
- La falta de API key de OpenAI (Fase 11) no bloquea nada — la app
  funciona igual sin ella, solo sin recomendaciones enriquecidas.

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

**93 tests, 0 fallas**, en `RunCoachCore`:

- Fases 2-3 (40): modelos, métricas, `RunState`, Simulation Engine.
- Fase 6 (8): `HeartRateMeasurementParser` — parsing GATT del Heart Rate
  Service.
- Fase 10 (11): `CoachEventDetector`, `CoachDecisionEngine`, escenario
  completo de 20 minutos.
- Fase 11 (14): request builder y response parser de OpenAI.
- Fase 19 (10): `CompletedRunTests` (2), `RunHistoryStoreTests` (6) — save/
  load/delete/orden/resiliencia ante archivos corruptos —, más 2 nuevos en
  `RunStateTests` para `averageHeartRateBPM`.
- Post-Fase 19 (10): `PaceTrendTests` (4, nuevo), 3 nuevos en
  `RunStateTests` (`paceTrend`), 2 nuevos en `CoachEventDetectorTests`
  (`.deteriorating`), 1 nuevo en `OpenAICoachRequestBuilderTests`.

Total actual verificado con `swift test`: **93 tests, 0 fallas** (incluye
todo lo de arriba).

## Build iOS

**Fases 4 a 11 y Fase 19 validadas en CI real** (todos los builds
verdes).

### Qué se agregó en Fase 19

**En `RunCoachCore` (testeado en Windows):**

- `RunState.averageHeartRateBPM`: promedio de FC de toda la carrera
  (distinto de `smoothedHeartRateBPM`, que es una media móvil reciente).
- `Split` ahora es `Codable` (antes solo `Equatable`/`Sendable`).
- `CompletedRun`: resumen `Codable` de una carrera terminada — duración,
  distancia, FC promedio, splits, `startedAt` como `Date` real (no
  relativo, a diferencia de `HeartRateSample`/`LocationSample`).
- `RunHistoryStore`: persiste `CompletedRun`s como JSON, un archivo por
  carrera, vía `FileManager` (portable — no SwiftData/Core Data). Testeado
  con directorios temporales reales en Windows.

**En `RunCoach-iOS` (solo compilado, no verificado — sin Mac):**

- `RunHistoryStore.documentsStore()`: decide el directorio real
  (`Documents/RunHistory`) — la única parte específica de iOS.
- `RunHistoryViewModel`: carga/borra carreras para la UI.
- `HistoryView`: lista real con fecha, duración, distancia, FC promedio,
  cantidad de splits, y borrado con swipe.
- `RunSessionViewModel.finishRun()`: guarda la carrera al terminar
  (parada a mano o fin natural de la simulación).

### Qué NO se hizo en Fase 19 (a propósito)

- Sin gráficos ni análisis visual de splits — solo texto, por ahora.
- Sin exportar/compartir carreras (a Strava, como archivo, etc.) — no
  estaba pedido.
- Sin límite de cuántas carreras se guardan — no hace falta para el
  volumen de un proyecto personal.

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
7. Timestamps como `TimeInterval` relativo, no `Date` (excepto en
   `CompletedRun.startedAt`, Fase 19 — ver decisión #24).
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
16. `AudioCoach` es infraestructura pura, sin lógica de decisión.
17. `CoachEventDetector` es sin memoria a propósito — toda la lógica
    temporal vive en `CoachDecisionEngine`.
18. Deduplicar por `CoachEvent.kind`, no por igualdad estricta — bug real
    encontrado por el test de escenario completo.
19. Armado/parseo de requests de OpenAI vive en `RunCoachCore` (portable,
    testeable); el cliente HTTP real vive en `RunCoach-iOS` — mismo
    patrón que Fase 6.
20. `OpenAICoachClient` reintenta una sola vez, solo ante fallas
    transitorias (no ante 401 ni JSON inesperado).
21. "Sin recomendación" (`nil`) es un resultado válido de
    `OpenAICoachClient`, nunca un error que se propague.
22. Firma automática vía API key de App Store Connect en Codemagic (Fase
    12, sin implementar todavía).
23. **Saltar Fases 12-18, adelantar Fase 19** — por instrucción explícita
    de Vicente de no pagar Apple Developer todavía. El roadmap deja de
    ser estrictamente secuencial a partir de acá.
24. Historial persistido como archivos JSON (`FileManager`), no
    SwiftData/Core Data — portable, testeable en Windows, suficiente para
    el volumen de un proyecto personal.
25. `PaceTrend` + `CoachEvent.deteriorating`, con el arbitraje de
    prioridad resuelto en `CoachEventDetector` (no en
    `CoachDecisionEngine`) — mismo patrón de separación que Fase 10.
26. `RunFormatting` compartido entre `RunView`/`HistoryView`/
    `RunDetailView` — corrige una inconsistencia real de formateo de
    ritmo encontrada en la revisión de calidad post-Fase 19.

## Arquitectura

Resumen en [docs/architecture.md](docs/architecture.md). El flujo
principal (datos → RunState → Coach Decision Engine → OpenAI → voz) está
completo desde Fase 11. Fase 19 le agrega persistencia — la app ya no
"olvida" cada carrera al cerrarse.

## Hardware

Sin cambios respecto a Fase 1. Ver [docs/hardware.md](docs/hardware.md).
Sin compras realizadas.

## Riesgos identificados

Ver tabla completa en [docs/architecture.md](docs/architecture.md#riesgos-identificados-fase-1).
Sin cambios nuevos de fondo. La parte de persistencia (Fase 19,
`RunCoachCore`) es de las más sólidamente testeadas del proyecto — a
diferencia de BLE/GPS/Audio/OpenAI, acá la lógica completa (guardar, leer,
ordenar, borrar, tolerar archivos corruptos) corre de verdad en cada
`swift test`, no solo compila.

## Archivos creados/modificados (Fase 19)

```
RunCoachCore/Sources/RunCoachCore/History/CompletedRun.swift        (nuevo)
RunCoachCore/Sources/RunCoachCore/History/RunHistoryStore.swift     (nuevo)
RunCoachCore/Sources/RunCoachCore/Models/Split.swift                (modificado: + Codable)
RunCoachCore/Sources/RunCoachCore/RunState.swift                    (modificado: + averageHeartRateBPM)
RunCoachCore/Tests/RunCoachCoreTests/CompletedRunTests.swift        (nuevo)
RunCoachCore/Tests/RunCoachCoreTests/RunHistoryStoreTests.swift     (nuevo)
RunCoachCore/Tests/RunCoachCoreTests/RunStateTests.swift            (modificado)
RunCoach-iOS/App/History/RunHistoryStore+Documents.swift            (nuevo)
RunCoach-iOS/App/History/RunHistoryViewModel.swift                  (nuevo)
RunCoach-iOS/App/Views/HistoryView.swift                            (reescrito)
RunCoach-iOS/App/ViewModels/RunSessionViewModel.swift                (modificado)
```

## Archivos creados/modificados (post-Fase 19)

```
RunCoachCore/Sources/RunCoachCore/Metrics/PaceTrend.swift               (nuevo)
RunCoachCore/Sources/RunCoachCore/Metrics/MovingAverage.swift           (modificado: + Sendable)
RunCoachCore/Sources/RunCoachCore/RunState.swift                        (modificado: + paceTrend, trend<T> helper)
RunCoachCore/Sources/RunCoachCore/Coach/CoachEvent.swift                (modificado: + .deteriorating)
RunCoachCore/Sources/RunCoachCore/Coach/CoachEventDetector.swift        (modificado: arbitraje de prioridad)
RunCoachCore/Sources/RunCoachCore/Coach/CoachDecisionEngine.swift       (doc comment actualizado)
RunCoachCore/Sources/RunCoachCore/OpenAI/OpenAICoachRequestBuilder.swift (modificado: caso .deteriorating)
RunCoachCore/Tests/RunCoachCoreTests/PaceTrendTests.swift               (nuevo)
RunCoachCore/Tests/RunCoachCoreTests/RunStateTests.swift                (modificado)
RunCoachCore/Tests/RunCoachCoreTests/CoachEventDetectorTests.swift      (modificado)
RunCoachCore/Tests/RunCoachCoreTests/OpenAICoachRequestBuilderTests.swift (modificado)
RunCoach-iOS/App/ViewModels/RunSessionViewModel.swift                   (modificado: frase de .deteriorating)
RunCoach-iOS/App/Views/RunDetailView.swift                              (nuevo)
RunCoach-iOS/App/Views/HistoryView.swift                                (modificado: NavigationLink a detalle)
RunCoach-iOS/App/Views/RunView.swift                                    (modificado: usa RunFormatting)
RunCoach-iOS/App/Formatting/RunFormatting.swift                         (nuevo)
```

## Git

Repo en GitHub: [github.com/vinfriend/RunCoach](https://github.com/vinfriend/RunCoach),
`main` en sync con `origin/main`. Codemagic conectado.

## Próxima tarea

Con el trabajo post-Fase 19 (Coach Decision Engine ampliado, detalle de
carrera, revisión de calidad) completado y commiteado, no hay más fases
avanzables sin firma/hardware según el roadmap original. Opciones para
cuando Vicente quiera seguir:

1. Retomar Fase 12 (pagar Apple Developer) cuando decida.
2. Pedir trabajo adicional dentro de lo ya alcanzable sin cuenta/hardware
   (pulir UI, más tests, más detectores del Coach Decision Engine —
   desviación de objetivo, por ejemplo, etc.) — a definir con Vicente, no
   asumir.
