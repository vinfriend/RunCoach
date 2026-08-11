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

Sin dependencias de UIKit/SwiftUI/CoreBluetooth/CoreLocation reales — solo
Foundation. Esto es lo que permite compilarlo y testearlo en Windows.
Contiene (a implementar en Fase 2/3):

- **Modelos de dominio**: `HeartRateSample`, `LocationSample`, `RunState`,
  `Split`, `PaceSample`.
- **Motor de métricas**: medias móviles, ritmo suavizado, velocidad,
  distancia, splits, relación ritmo/HR.
- **Detección de tendencias/eventos**: tasa de cambio de HR, deterioro,
  recuperación, desviación de objetivo.
- **Coach Decision Engine**: prioridades, cooldown, deduplicación, contexto
  reciente, decisión hablar/callarse. La salida más común debe ser "no
  hablar".
- **Simulation Engine**: fuente de datos sintética con escenarios
  reproducibles (ver [docs/testing.md](testing.md)).
- **Abstracciones de fuente de datos**: protocolos `HeartRateSource` y
  `LocationSource` que tanto la simulación como el BLE/GPS reales
  implementan, para que el motor sea agnóstico del origen de los datos.

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
protocol HeartRateSource {
    var bpmPublisher: AnyPublisher<HeartRateSample, Never> { get }
    func start()
    func stop()
}
```

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
