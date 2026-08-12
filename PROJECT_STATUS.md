# PROJECT_STATUS.md — fuente de verdad del progreso

> Leer esto (junto con [CLAUDE.md](CLAUDE.md)) antes de empezar cualquier
> sesión nueva. Ver también `git status` y `git log --oneline` para el
> estado exacto del código.

## Fase actual

**Fases 0 a 9** — **completadas**. Resumen rápido:

- **0-1**: entorno Windows listo, arquitectura e investigación.
- **2-3**: `RunCoachCore` (modelos, métricas, `RunState`, Simulation
  Engine) — 40 tests en verde en Windows.
- **4-5**: proyecto iOS + CI en Codemagic, UI SwiftUI con pantalla de
  carrera simulada.
- **6-7**: `BLEHeartRateSource` (CoreBluetooth) y `GPSLocationSource`
  (CoreLocation) — validados solo por compilación en CI, sin hardware
  real todavía. `HeartRateMeasurementParser` (parsing GATT) sí testeado
  en Windows.
- **8**: `RunSessionViewModel` soporta modo real (BLE+GPS con `Date` de
  referencia compartido) además del simulado; `RunView` deja elegir.
- **9**: `AudioCoach` (voz `es-AR`) anuncia eventos mecánicos —
  inicio/fin de carrera, cada split. Sin lógica de decisión todavía.

**Fase 10** (Coach Decision Engine) — **completada**. Build de Codemagic
para el commit `9b61391` terminó `finished` sin pasos fallidos (1m 26s).
La pieza central del proyecto, y la primera de las últimas cinco en vivir
enteramente en `RunCoachCore` — **totalmente testeable en Windows**: 59
tests en verde (11 nuevos). `CoachDecisionEngine` decide
`.silence`/`.speak(event)` combinando deduplicación, cooldown, y contexto
reciente. Validado contra el escenario completo de 20 minutos: pocas
intervenciones, no una por muestra. Ya wireado a `AudioCoach` en
`RunSessionViewModel`.

**Bug real encontrado y corregido durante esta fase** (ver "Decisiones
tomadas" #17): la deduplicación comparaba eventos por igualdad estricta
(incluyendo el BPM exacto, que cambia en cada muestra), así que hablaba
10 veces en vez de 2-3. El test de escenario completo lo atrapó
inmediatamente.

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

**59 tests, 0 fallas**, en `RunCoachCore`:

- Fases 2-3 (40): modelos, métricas, `RunState`, Simulation Engine.
- Fase 6 (8): `HeartRateMeasurementParser` — parsing GATT del Heart Rate
  Service.
- Fase 10 (11): `CoachEventDetectorTests` (4), `CoachDecisionEngineTests`
  (6), y el test de escenario completo de 20 minutos (1) que atrapó el
  bug de deduplicación — ver docs/decisions.md.

## Build iOS

**Fases 4 a 10 validadas en CI real** (todos los builds verdes).

### Qué se agregó en Fase 10

**En `RunCoachCore` (testeado en Windows):**

- `CoachEvent` (`Coach/`): `effortRising`/`effortFalling`, con un `.kind`
  para deduplicar sin comparar el BPM exacto.
- `CoachEventDetector`: función pura, sin memoria, que clasifica el
  `RunState` actual en un evento candidato (o `nil`).
- `CoachDecisionEngine`: decide `.silence`/`.speak(event)` combinando
  deduplicación por tipo de evento, cooldown temporal (90s por defecto),
  y contexto reciente (`recentSpokenEvents`, historial acotado). Un
  evento bloqueado por cooldown se reintenta después, no se pierde.

**En `RunCoach-iOS` (solo compilado, no verificado funcionalmente):**

- `RunSessionViewModel`: consulta `CoachDecisionEngine` en cada
  `refresh()`; cuando decide `.speak`, traduce el evento a español y se
  lo pasa a `AudioCoach`. Se resetea un `CoachDecisionEngine` nuevo en
  cada `start*()`, igual que `RunState`.

### Qué NO se hizo en Fase 10 (a propósito)

- **Arbitraje de prioridades entre eventos que compitan entre sí** — hoy
  solo hay un detector (tendencia de FC), así que nunca hay dos
  candidatos simultáneos que priorizar de verdad. Se vuelve relevante con
  más detectores o con las recomendaciones de OpenAI (Fase 11).
- Nada de OpenAI todavía — Fase 11.
- Ningún detector nuevo más allá de tendencia de FC (pace deviation,
  anomalías) — no estaba pedido para esta fase, y sin datos reales es
  difícil calibrar umbrales con confianza.

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
16. `AudioCoach` es infraestructura pura, sin lógica de decisión.
17. `CoachEventDetector` es sin memoria a propósito — toda la lógica
    temporal vive en `CoachDecisionEngine`, para que un evento bloqueado
    por cooldown se pueda reintentar en vez de perderse.
18. Deduplicar por `CoachEvent.kind`, no por igualdad estricta — bug real
    encontrado por el test de escenario completo (hablaba 10 veces en vez
    de 2-3 porque el BPM asociado cambiaba en cada muestra).

## Arquitectura

Resumen en [docs/architecture.md](docs/architecture.md). Con Fase 10, la
pieza que le da sentido a todo el proyecto —"cuándo vale la pena que el
coach hable"— ya existe y está testeada de verdad. Falta conectarla con
OpenAI (Fase 11) para que lo que dice sea más rico que frases fijas en
español.

## Hardware

Sin cambios respecto a Fase 1. Ver [docs/hardware.md](docs/hardware.md).
Sin compras realizadas.

## Riesgos identificados

Ver tabla completa en [docs/architecture.md](docs/architecture.md#riesgos-identificados-fase-1).
Sin cambios nuevos — la parte de `RunCoach-iOS` de Fase 10 hereda el mismo
riesgo de "código nunca antes escuchado" de Fases 6-9. La parte de
`RunCoachCore`, en cambio, es la más sólidamente verificada del proyecto
hasta ahora.

## Archivos creados/modificados (Fase 10)

```
RunCoachCore/Sources/RunCoachCore/Coach/CoachEvent.swift            (nuevo)
RunCoachCore/Sources/RunCoachCore/Coach/CoachEventDetector.swift    (nuevo)
RunCoachCore/Sources/RunCoachCore/Coach/CoachDecision.swift         (nuevo)
RunCoachCore/Sources/RunCoachCore/Coach/CoachDecisionEngine.swift   (nuevo)
RunCoachCore/Tests/RunCoachCoreTests/CoachEventDetectorTests.swift  (nuevo)
RunCoachCore/Tests/RunCoachCoreTests/CoachDecisionEngineTests.swift (nuevo)
RunCoachCore/Tests/RunCoachCoreTests/ReferenceScenarioTests.swift   (modificado)
RunCoach-iOS/App/ViewModels/RunSessionViewModel.swift               (modificado)
```

## Git

Repo en GitHub: [github.com/vinfriend/RunCoach](https://github.com/vinfriend/RunCoach),
`main` en sync con `origin/main`. Codemagic conectado.

## Próxima tarea

Esperar "Continuar con Fase 11" (OpenAI) de Vicente — la primera fase que
va a requerir que Vicente cree una cuenta/API key de OpenAI (con
autorización explícita, nunca guardada en Git).
