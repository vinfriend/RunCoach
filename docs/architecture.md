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

**Pendiente (fases futuras, explícitamente fuera de alcance de Fase 2):**

- **Simulation Engine** (Fase 3): fuente de datos sintética con escenarios
  reproducibles (ver [docs/testing.md](testing.md)).
- **Detección de eventos** más allá de la tendencia de FC: deterioro,
  recuperación, desviación de objetivo (Fase 8, Run Data Engine completo).
- **Coach Decision Engine** (Fase 10): prioridades, cooldown, deduplicación,
  contexto reciente, decisión hablar/callarse. La salida más común debe ser
  "no hablar".

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

Implementaciones previstas:

- `MockHeartRateSource` — Fase 3, alimenta desde el Simulation Engine.
- `BLEHeartRateSource` — Fase 6, cualquier sensor que exponga el servicio
  Bluetooth estándar Heart Rate Service (`0x180D`) con la característica
  Heart Rate Measurement (`0x2A37`). Esto cubre WHOOP (con HR Broadcast
  activado), Polar H10/Verity Sense, Garmin HRM-Dual/Pro, Scosche Rhythm24,
  Wahoo TICKR, etc. — ver [docs/hardware.md](hardware.md).

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
