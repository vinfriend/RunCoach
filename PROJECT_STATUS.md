# PROJECT_STATUS.md — fuente de verdad del progreso

> Leer esto (junto con [CLAUDE.md](CLAUDE.md)) antes de empezar cualquier
> sesión nueva. Ver también `git status` y `git log --oneline` para el
> estado exacto del código.

## Fase actual

**Fases 0 a 10** — **completadas**. Resumen rápido:

- **0-1**: entorno Windows listo, arquitectura e investigación.
- **2-3**: `RunCoachCore` (modelos, métricas, `RunState`, Simulation
  Engine) — 40 tests.
- **4-5**: proyecto iOS + CI en Codemagic, UI SwiftUI con carrera simulada.
- **6-7**: `BLEHeartRateSource`/`GPSLocationSource` — solo compilación en
  CI. `HeartRateMeasurementParser` testeado en Windows (8 tests).
- **8**: modo real (BLE+GPS con `Date` de referencia compartido) conectado
  a la UI.
- **9**: `AudioCoach` (voz `es-AR`) anuncia eventos mecánicos.
- **10**: `CoachDecisionEngine` — la pieza central, decide cuándo hablar
  (11 tests, incluyendo un bug real corregido — ver docs/decisions.md).

**Fase 11** (OpenAI) — **completada** (en el sentido de "compila"). Mismo
patrón que Fase 6 (BLE): la lógica de armado/parseo de requests vive en
`RunCoachCore` (**73 tests en total**), el cliente HTTP real vive en
`RunCoach-iOS`. Sin API key configurada todavía.

**Fase 12** (Apple Developer / firma) — **bloqueada esperando a
Vicente**. Primera fase gateada casi por completo por una acción suya:
inscribirse en el Apple Developer Program (USD 99/año, pago +
verificación de identidad, 1-3 días de aprobación) y, una vez aprobado,
crear una API key de App Store Connect para que Codemagic pueda firmar
automáticamente. Ver [docs/ios-build.md](docs/ios-build.md#fase-12--apple-developer--firma)
para el plan completo investigado. No hay nada que yo pueda avanzar acá
sin esa cuenta — ver el mensaje de esta sesión para la acción exacta que
le pedí a Vicente.

Nota de proceso (desde Fase 5): el trigger automático por `push` de
Codemagic no dispara solo — hay que iniciar el build a mano desde el
dashboard ("Start new build") cada vez.

## Último commit estable

Ver `git log --oneline -1` para el hash exacto.

## Bloqueos

- **Fase 12 bloqueada esperando que Vicente se inscriba en el Apple
  Developer Program.** No es algo que yo pueda hacer ni acelerar — pago,
  verificación de identidad, y una aprobación de Apple que toma 1-3 días.
  Ver [docs/ios-build.md](docs/ios-build.md#fase-12--apple-developer--firma).
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

**73 tests, 0 fallas**, en `RunCoachCore`:

- Fases 2-3 (40): modelos, métricas, `RunState`, Simulation Engine.
- Fase 6 (8): `HeartRateMeasurementParser` — parsing GATT del Heart Rate
  Service.
- Fase 10 (11): `CoachEventDetector`, `CoachDecisionEngine`, escenario
  completo de 20 minutos.
- Fase 11 (14): `OpenAICoachRequestBuilderTests` (7) — forma del JSON,
  contenido del prompt según el evento; `OpenAICoachResponseParserTests`
  (7) — respuestas válidas, malformadas, vacías.

## Build iOS

**Fases 4 a 11 validadas en CI real** (todos los builds verdes).

### Qué se agregó en Fase 11

**En `RunCoachCore` (testeado en Windows):**

- `CoachEventSummary`: snapshot estructurado del `RunState` en el
  instante de la decisión (no las muestras crudas).
- `OpenAIChatMessage`/`OpenAIChatRequest`/`OpenAIChatResponse`: tipos
  `Codable` que reflejan el formato de OpenAI Chat Completions.
- `OpenAICoachRequestBuilder`: arma el prompt (system + user) — modelo
  `gpt-4o-mini`, `max_tokens: 60` (control de costo deliberado).
- `OpenAICoachResponseParser`: decodifica la respuesta en un
  `CoachRecommendation`, `nil` ante cualquier forma inesperada.

**En `RunCoach-iOS` (solo compilado, no verificado — sin API key ni Mac):**

- `OpenAIAPIKeyStore`: Keychain, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
- `OpenAICoachClient`: `URLSession` con timeout de 5s y **un** reintento
  prudente (solo ante fallas transitorias: timeout, sin conexión, 429,
  5xx — nunca ante 401 o JSON inesperado). Nunca lanza: cualquier falla
  colapsa a `nil`.
- `RunSessionViewModel`: al decidir `.speak(event)`, lanza un `Task`
  aparte que intenta OpenAI y cae a la frase fija si no hay respuesta a
  tiempo.
- `SettingsView`: campo real (ya no placeholder) para pegar la API key.

### Qué NO se hizo en Fase 11 (a propósito)

- Nada de voz conversacional ni Realtime API — sigue siendo texto → TTS
  local, tal como pedía el prompt original.
- Sin control de cuota/presupuesto explícito más allá de lo que ya acota
  `CoachDecisionEngine` — no hace falta más para un proyecto personal en
  esta etapa.
- Sin telemetría de latencia/costo real — no se puede medir sin una API
  key real y sin correr la app de verdad.

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
    temporal vive en `CoachDecisionEngine`.
18. Deduplicar por `CoachEvent.kind`, no por igualdad estricta — bug real
    encontrado por el test de escenario completo.
19. Armado/parseo de requests de OpenAI vive en `RunCoachCore` (portable,
    testeable); el cliente HTTP real vive en `RunCoach-iOS` — mismo
    patrón que Fase 6.
20. `OpenAICoachClient` reintenta una sola vez, solo ante fallas
    transitorias (no ante 401 ni JSON inesperado).
21. "Sin recomendación" (`nil`) es un resultado válido de
    `OpenAICoachClient`, nunca un error que se propague — simplifica el
    llamador y refuerza que la red nunca bloquea nada.
22. Firma automática vía API key de App Store Connect en Codemagic (Fase
    12), en vez de exportar/subir certificados `.p12` a mano — más simple
    y es el método que recomienda la documentación de Codemagic.

## Arquitectura

Resumen en [docs/architecture.md](docs/architecture.md). Con Fase 11, el
flujo completo previsto desde el prompt original ya existe en código:
datos → RunState → Coach Decision Engine → resumen estructurado → OpenAI
→ recomendación → voz. Falta la firma/distribución (Fases 12-13) para
poder probarlo de verdad en un iPhone.

## Hardware

Sin cambios respecto a Fase 1. Ver [docs/hardware.md](docs/hardware.md).
Sin compras realizadas.

## Riesgos identificados

Ver tabla completa en [docs/architecture.md](docs/architecture.md#riesgos-identificados-fase-1).
`OpenAICoachClient` hereda el mismo riesgo de "código nunca antes
ejecutado" que BLE/GPS/Audio — agravado porque ni siquiera hay una API
key para probarlo cuando llegue el momento de tener un iPhone. La parte de
`RunCoachCore` (request/response), en cambio, está sólidamente testeada.

## Archivos creados/modificados (Fase 11)

```
RunCoachCore/Sources/RunCoachCore/OpenAI/CoachEventSummary.swift            (nuevo)
RunCoachCore/Sources/RunCoachCore/OpenAI/OpenAIChatModels.swift             (nuevo)
RunCoachCore/Sources/RunCoachCore/OpenAI/OpenAICoachRequestBuilder.swift    (nuevo)
RunCoachCore/Sources/RunCoachCore/OpenAI/OpenAICoachResponseParser.swift    (nuevo)
RunCoachCore/Sources/RunCoachCore/OpenAI/CoachRecommendation.swift          (nuevo)
RunCoachCore/Tests/RunCoachCoreTests/OpenAICoachRequestBuilderTests.swift   (nuevo)
RunCoachCore/Tests/RunCoachCoreTests/OpenAICoachResponseParserTests.swift   (nuevo)
RunCoach-iOS/App/OpenAI/OpenAIAPIKeyStore.swift                             (nuevo)
RunCoach-iOS/App/OpenAI/OpenAICoachClient.swift                             (nuevo)
RunCoach-iOS/App/ViewModels/RunSessionViewModel.swift                       (modificado)
RunCoach-iOS/App/Views/SettingsView.swift                                   (modificado)
```

## Git

Repo en GitHub: [github.com/vinfriend/RunCoach](https://github.com/vinfriend/RunCoach),
`main` en sync con `origin/main`. Codemagic conectado.

## Próxima tarea

Esperando que Vicente complete el Paso 1 de
[docs/ios-build.md#fase-12](docs/ios-build.md#fase-12--apple-developer--firma):
inscribirse en el Apple Developer Program. Cuando esté aprobado (1-3
días), me pasa el Team ID y seguimos con el Paso 2 (API key de App Store
Connect → Codemagic) y el Paso 3 (actualizar `project.yml`/`codemagic.yaml`
para firma automática).

