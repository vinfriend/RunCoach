# Arquitectura

## Visión general

```
┌─────────────┐      BLE (Heart Rate Service 0x180D)
│  Pulsera /  │ ───────────────────────────────────┐
│  sensor HR  │                                     │
│ (sin        │                                     ▼
│  pantalla)  │                          ┌───────────────────────┐
└─────────────┘                          │        iPhone          │
                                          │                         │
┌─────────────┐   GPS / CoreLocation     │  ┌───────────────────┐ │
│   Satélites │ ───────────────────────► │  │   RunCoach-iOS     │ │
│     GPS     │                          │  │  (SwiftUI, BLE,    │ │
└─────────────┘                          │  │   GPS, Audio)      │ │
                                          │  └─────────┬──────────┘ │
                                          │            │            │
                                          │            ▼            │
                                          │  ┌───────────────────┐ │
                                          │  │   RunCoachCore     │ │
                                          │  │ (métricas, RunState,│ │
                                          │  │  Coach Decision     │ │
                                          │  │  Engine, eventos)   │ │
                                          │  └─────────┬──────────┘ │
                                          │            │ solo en    │
                                          │            │ eventos    │
                                          │            │ relevantes │
                                          │            ▼            │
                                          │      OpenAI API         │
                                          │  (resumen estructurado  │
                                          │   → recomendación)      │
                                          └────────────┬────────────┘
                                                        │ AVSpeechSynthesizer
                                                        ▼
                                                    AirPods
```

## Principio central

El motor de carrera (RunCoachCore) **nunca depende de la red**. Todo el
cálculo de métricas, detección de tendencias/eventos y decisión de hablar
ocurre localmente y de forma determinista. OpenAI es un consultor opcional
que se invoca solo cuando el Coach Decision Engine decide que hay algo
suficientemente importante como para justificar una recomendación more
elaborada. Si la red falla o tarda, el motor sigue corriendo sin bloquearse
(ver [docs/openai.md](openai.md)).

## Módulos

### RunCoachCore (Swift Package portable)

Sin dependencias de UIKit/SwiftUI/CoreBluetooth/CoreLocation/Combine
reales — solo Foundation. Esto es lo que permite compilarlo y testearlo en
Windows.

**Implementado (Fase 2):**

- **Modelos de dominio**: `HeartRateSample`, `LocationSample`, `Split`
  (`Models/`). Timestamps en `TimeInterval` (segundos desde el inicio de la
  carrera, no `Date`) — determinista y fácil de testear, y es lo que el
  Simulation Engine (Fase 3) va a poder controlar directamente.
- **Utilidades de métricas** (`Metrics/`): `MovingAverage` (media móvil
  genérica de ventana fija), `GeoDistance` (distancia Haversine entre
  coordenadas), `HeartRateTrend` (clasificación rising/falling/stable con
  umbral configurable).
- **`RunState`**: el motor de ingestión — acumula `HeartRateSample`/
  `LocationSample`, calcula distancia total, ritmo suavizado, FC suavizada,
  tendencia de FC (comparando el promedio reciente contra el de hace N
  segundos), y genera `Split`s automáticamente al cruzar el umbral de
  distancia configurado (1000m por defecto).
- **Abstracciones de fuente de datos**: protocolos `HeartRateSource` y
  `LocationSource` (`Sources/`) que tanto la simulación (Fase 3) como el
  BLE/GPS reales (Fases 6-7) van a implementar, para que `RunState` sea
  agnóstico del origen de los datos.

**Implementado (Fase 3):**

- **Simulation Engine** (`Simulation/`): `ScenarioSegment` (interpolación
  lineal de ritmo/FC, pérdida de señal, anomalías puntuales), `Scenario`
  (secuencia de segmentos, incluye `Scenario.referenceRun` — el escenario
  de 20 minutos de [docs/testing.md](testing.md)), `ScenarioSimulator`
  (genera `[HeartRateSample]`/`[LocationSample]` deterministas a partir de
  un escenario), y `MockHeartRateSource`/`MockLocationSource` (implementan
  los protocolos de Fase 2 reproduciendo esas muestras).

**Implementado (Fase 6):**

- **BLE** (`BLE/`): `HeartRateMeasurementParser` — decodifica el payload
  de la característica Heart Rate Measurement (`0x2A37`) del Bluetooth
  Heart Rate Service estándar (`0x180D`), según la spec del Bluetooth SIG.
  Lógica pura de bytes, sin CoreBluetooth — testeada en Windows. El
  `CBCentralManager` que sí depende de CoreBluetooth vive en
  `RunCoach-iOS` (`BLEHeartRateSource`).

**Implementado (Fase 10 — Coach Decision Engine):**

- **`CoachEvent`** (`Coach/`): los tipos de evento que el motor puede
  detectar — hoy, `effortRising`/`effortFalling` (basados en
  `RunState.heartRateTrend`). Sin texto ni idioma — eso lo genera
  `RunCoach-iOS`.
- **`CoachEventDetector`**: función pura y sin memoria que clasifica el
  `RunState` actual en un `CoachEvent` candidato (o `nil`). Separado
  deliberadamente de la decisión de si vale la pena decirlo — ver
  `CoachDecisionEngine` y [docs/decisions.md](decisions.md).
- **`CoachDecisionEngine`**: la pieza central del proyecto. Decide
  `.silence` o `.speak(event)` combinando deduplicación (por *tipo* de
  evento, no por igualdad estricta — ver el bug corregido en
  decisions.md), cooldown temporal, y un historial acotado de eventos
  hablados (`recentSpokenEvents`, "contexto reciente"). Un evento
  bloqueado por cooldown no se pierde: se reintenta en la próxima
  evaluación si la condición sigue vigente.
- Validado contra el escenario de referencia completo de 20 minutos: la
  salida más frecuente es `.silence`, con como máximo 3 intervenciones en
  toda la carrera (criterio de [docs/testing.md](testing.md)).
- **Sin implementar**: arbitraje de prioridades entre eventos que
  compitan entre sí — hoy solo hay un detector (tendencia de FC), así que
  nunca hay dos candidatos simultáneos que priorizar. Se vuelve relevante
  con más detectores o con las recomendaciones de OpenAI (Fase 11).

**Implementado (Fase 11 — OpenAI):**

- **`CoachEventSummary`, `OpenAIChat*` (Codable), `OpenAICoachRequestBuilder`,
  `OpenAICoachResponseParser`, `CoachRecommendation`** (`OpenAI/`): arman
  el request y parsean la respuesta de OpenAI Chat Completions. Lógica
  pura de texto/JSON, sin `URLSession` — 14 tests en Windows. El cliente
  HTTP real (`OpenAICoachClient`, con timeout/retry) vive en
  `RunCoach-iOS`, mismo patrón que `HeartRateMeasurementParser`/
  `BLEHeartRateSource` en Fase 6. Ver [docs/openai.md](openai.md) para el
  detalle completo del diseño y cómo se cumple cada requisito no
  negociable (timeout, fallback, retry prudente, control de costo).

**Pendiente (fases futuras):**

- **Detección de eventos** más allá de la tendencia de FC: desviación de
  objetivo, aceleraciones/anomalías puntuales (posible ampliación futura
  de `CoachEventDetector`, no planificada todavía).

### RunCoach-iOS (proyecto Xcode, generado con XcodeGen)

Todo lo específico de Apple:

- SwiftUI (UI de carrera, configuración, historial).
- CoreBluetooth (`BLEHeartRateSource`, descubrimiento/conexión/reconexión).
- CoreLocation (GPS en background, `allowsBackgroundLocationUpdates`).
- AVFoundation / `AVSpeechSynthesizer` (audio coach por AirPods).
- Background modes (`bluetooth-central`, `location`, `audio`).
- Keychain (guardar la API key de OpenAI de forma segura, nunca en texto
  plano ni en Git).
- Ciclo de vida iOS, permisos, manejo de interrupciones de audio/llamadas.

**Implementado (Fase 5):**

- `ContentView` (`TabView`): Correr / Historial / Ajustes.
- `RunView` + `RunSessionViewModel`: pantalla de carrera funcional,
  alimentada por el Simulation Engine de `RunCoachCore` (Fase 3) con
  pacing en tiempo real acelerado — ver [docs/decisions.md](decisions.md).
  Todavía sin BLE/GPS reales (Fases 6-7).
- `HistoryView`/`SettingsView`: placeholders que señalan explícitamente
  qué fase futura los implementa de verdad.

**Implementado (Fase 6-7):**

- `BLEHeartRateSource` (Fase 6, `App/BLE/`) — ver detalle en la sección
  "HeartRateSource" abajo.
- `GPSLocationSource` (Fase 7, `App/GPS/`) — implementa `LocationSource`
  con `CLLocationManager`. Pide autorización "When In Use" (no "Always"
  todavía — eso, junto con la validación real de background, es la Fase
  15), `activityType: .fitness`, `pausesLocationUpdatesAutomatically:
  false` para no perder tracking en semáforos/esperas. A diferencia de
  BLE, el simulador de iOS sí puede simular una ubicación GPS (Xcode:
  Debug > Simulate Location) — pero sin Mac para abrir Xcode, sigue sin
  poder probarse de este lado, igual que BLE.

**Implementado (Fase 8 — Run Data Engine completo):**

`RunSessionViewModel` ahora soporta dos modos (`RunMode`):

- `.simulated` — el de Fase 5, sin cambios de fondo.
- `.real` — crea un `BLEHeartRateSource` y un `GPSLocationSource`, les fija
  el **mismo** `Date` de referencia antes de llamar `start()` en cada uno
  (resolviendo la nota pendiente de Fase 6 sobre timestamps comparables
  entre fuentes — ver [docs/decisions.md](decisions.md)), y alimenta el
  mismo `RunState` con lo que vayan entregando.

`RunView` deja elegir el modo desde la pantalla inicial. El modo real
sigue sin poder validarse funcionalmente — sin sensor ni GPS conectados no
va a mostrar nada, y no hay forma de confirmar que funciona sin hardware
real (Fase 14) ni de verlo correr en simulador (BLE no anda ahí). El
"motor" está completo; que ande de verdad es otra historia, pendiente de
Fase 14.

**Implementado (Fase 9 — Audio Coach):**

`AudioCoach` (`App/Audio/`) envuelve `AVSpeechSynthesizer` con voz en
español (`es-AR` por defecto) y una `AVAudioSession` configurada como
`.playback` + `.spokenAudio` con `.duckOthers` — pensada para sonar aunque
el iPhone esté en silencio, bajando (no cortando) otro audio que esté
sonando. **Es solo infraestructura de voz: no decide nada.**
`RunSessionViewModel` la usa para anunciar eventos mecánicos que
`RunCoachCore` ya calcula — inicio/fin de carrera, cada split completado
con su ritmo — sin ninguna lógica de "¿vale la pena hablar ahora?".

A diferencia de BLE, el simulador de iOS sí reproduce audio — pero sin Mac
para abrir Xcode, sigue sin poder escucharse ni validarse de este lado.

**Implementado (Fase 10 — Coach Decision Engine):**

La pieza central del proyecto, y la primera de las últimas cinco fases que
vive enteramente en `RunCoachCore` — **totalmente testeable en Windows**,
a diferencia de BLE/GPS/Audio (Fases 6-9). Ver
[docs/decisions.md](decisions.md) para el detalle de diseño, incluyendo un
bug real encontrado y corregido durante la implementación.

`RunSessionViewModel` consulta `CoachDecisionEngine` en cada `refresh()` y,
cuando decide `.speak(event)`, traduce el `CoachEvent` a español y se lo
pasa a `AudioCoach` — el mismo mecanismo de Fase 9, ahora con criterio real
detrás en vez de solo eventos mecánicos.

Como no hay Mac local, todo el código de `RunCoach-iOS` (incluyendo esta
integración) solo se valida por CI (compila para simulador) — nunca se vio
corriendo, ni se escuchó sonar. `RunCoachCore`, en cambio, sí está
verificado de verdad: ver PROJECT_STATUS.md para el resultado del build de
CI y el detalle de tests.

**Implementado (Fase 11 — OpenAI):**

`OpenAIAPIKeyStore` (`App/OpenAI/`, Keychain) y `OpenAICoachClient`
(`URLSession`, timeout de 5s, un reintento prudente). Cuando
`CoachDecisionEngine` decide `.speak(event)`, `RunSessionViewModel` intenta
`OpenAICoachClient` en un `Task` aparte (nunca bloquea `refresh()`); si
responde a tiempo, dice esa recomendación, si no, cae a la frase fija de
Fase 9-10. `SettingsView` tiene un campo real (no placeholder) para pegar
la API key, guardada solo en el Keychain de ese iPhone.

Ver [docs/openai.md](openai.md) para el diseño completo. Sin validar
contra la API real — no hay API key creada para este proyecto todavía (eso
requiere autorización explícita de Vicente, nunca autónomo).

## HeartRateSource: independencia de marca

```swift
public protocol HeartRateSource: AnyObject {
    var onSample: ((HeartRateSample) -> Void)? { get set }
    func start()
    func stop()
}
```

Se usa un closure simple en vez de Combine's `AnyPublisher` — Combine es
exclusivo de plataformas Apple y no existe en el toolchain de Swift para
Windows/Linux, así que hubiera roto la posibilidad de testear
`RunCoachCore` fuera de macOS. `LocationSource` sigue el mismo patrón.

Implementaciones:

- `MockHeartRateSource` (Fase 3) — alimenta desde el Simulation Engine.
- `BLEHeartRateSource` (Fase 6, `RunCoach-iOS/App/BLE/`) — CoreBluetooth
  contra el servicio Bluetooth estándar Heart Rate Service (`0x180D`) con
  la característica Heart Rate Measurement (`0x2A37`). Esto cubre WHOOP
  (con HR Broadcast activado), Polar H10/Verity Sense, Garmin HRM-Dual/Pro,
  Scosche Rhythm24, Wahoo TICKR, etc. — ver [docs/hardware.md](hardware.md).
  El parsing del payload (`HeartRateMeasurementParser`) vive en
  `RunCoachCore` porque es lógica pura de bytes, sin dependencia de
  CoreBluetooth — se testea en Windows. Lo que sí es exclusivo de Apple
  (`CBCentralManager`, escaneo, conexión, notificaciones) vive en
  `RunCoach-iOS`, sin poder probarse ni en el simulador de iOS (no tiene
  radio Bluetooth real) — solo se valida por compilación hasta la Fase 14
  con hardware de verdad.

El resto del proyecto (UI, Coach Decision Engine, RunCoachCore) solo conoce
el protocolo `HeartRateSource`, nunca una marca concreta.

## CI / build sin Mac local

Windows → GitHub → Codemagic (macOS cloud) → Xcode build → App Store Connect
→ TestFlight → iPhone. Detalle completo en
[docs/ios-build.md](ios-build.md).

## Riesgos identificados (Fase 1)

| Riesgo | Impacto | Mitigación |
|---|---|---|
| Apple restringe/rechaza uso de ubicación en background sin justificación clara | Alto — bloquea TestFlight/App Store | Pedir primero "When In Use", pedir "Always" solo con propósito claro más adelante; justificación de privacidad explícita en el review |
| Sensor BLE elegido no cumple el perfil estándar | Alto — rompe la abstracción `HeartRateSource` | Verificar HR Service 0x180D antes de comprar cualquier hardware (ya validado para WHOOP con Broadcast, Polar, Garmin, Scosche — ver hardware.md) |
| `swift build`/`swift test` en Windows con divergencias vs. macOS | Medio | Mantener RunCoachCore sin imports de Apple frameworks; validar también en CI Codemagic cuando exista |
| Costos de Codemagic si se itera mucho | Bajo/Medio | Free tier: 500 min macOS/mes; monitorear consumo, documentar en decisions.md si se supera |
| Costos/latencia de OpenAI | Bajo (Fase 11, aún no integrado) | Diseño ya contempla resumen estructurado, no streaming de cada muestra; timeout + fallback offline |
| XcodeGen mantenimiento comunitario más lento que Tuist | Bajo | Empezar con XcodeGen por simplicidad; documentar migración a Tuist si el proyecto crece en complejidad |

## Cambios de arquitectura respecto al roadmap original

Ninguno todavía. Cualquier cambio de orden de fases o de herramienta elegida
se documenta en [docs/decisions.md](decisions.md).
