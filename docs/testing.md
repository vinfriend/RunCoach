# Estrategia de testing

## Niveles

1. **Unit tests de RunCoachCore** (`swift test`, corren en Windows y en CI).
   Cubren modelos, cálculo de métricas, detección de eventos, y el Coach
   Decision Engine con entradas sintéticas controladas.
2. **Tests del Simulation Engine**: escenarios reproducibles (ver abajo) que
   ejercitan el motor completo de punta a punta sin hardware.
3. **Tests de UI/integración iOS**: correrán en Codemagic (macOS), no en
   Windows. Se agregan a partir de la Fase 5.
4. **Pruebas reales** (Fases 17-18): correr con hardware real. Se documentan
   en [docs/real-world-tests.md](real-world-tests.md), no reemplazan a los
   tests automáticos.

## Simulation Mode (obligatorio antes de hardware real)

El mismo motor (`RunCoachCore`) debe poder consumir tanto una fuente
simulada como una real, a través de los protocolos `HeartRateSource` /
`LocationSource` (ver [docs/architecture.md](architecture.md)). El
Simulation Engine debe poder generar, de forma determinista y reproducible:

- Progresión de tiempo controlada (no depende del reloj real).
- Frecuencia cardíaca sintética con tendencias (subida, estable, bajada).
- Trayectoria GPS sintética → distancia y ritmo derivados.
- Fatiga / aceleraciones / recuperación.
- Anomalías (picos de HR, saltos de posición).
- Pérdida temporal de señal (BLE o GPS) para probar la resiliencia del
  motor.

### Escenario de referencia (del prompt original)

```
0–5 min:   ritmo suave, FC estable
5–10 min:  aumento de ritmo, FC sube
10–15 min: ritmo estable, FC sigue subiendo
15 min:    evento importante (ej. deterioro/desviación significativa)
15–20 min: recuperación
```

**Implementado en Fase 3** como `Scenario.referenceRun`
(`RunCoachCore/Sources/RunCoachCore/Simulation/Scenario.swift`): cuatro
segmentos de 5 minutos cada uno (calentamiento, aumento de ritmo, esfuerzo
sostenido, recuperación). El "evento importante" del minuto 15 se modela
como **deriva cardíaca sostenida** (la FC sigue subiendo aunque el ritmo ya
se estabilizó, del minuto 10 al 15) — es una tendencia real de varios
minutos, no un glitch puntual, y es lo que el Coach Decision Engine (Fase
10) va a tener que detectar vía `RunState.heartRateTrend`.

Cubierto por `ReferenceScenarioTests` (`RunCoachCoreTests`): duración total
de 20 minutos, distancia/splits plausibles corriendo el escenario completo
a través de `MockHeartRateSource`/`MockLocationSource` → `RunState`, y que
la tendencia de FC sea `.stable` durante el calentamiento, `.rising`
durante el aumento de ritmo, y `.falling` durante la recuperación.

Este escenario sirve como "golden path" para validar el Coach Decision
Engine (Fase 10, implementado): se espera que NO hable en los primeros
minutos, y que genere unas pocas intervenciones relevantes en total.
Cubierto por `testCoachDecisionEngineSpeaksSparinglyAcrossFullRun`
(`ReferenceScenarioTests`).

## Criterio de "no hablar por defecto"

**Implementado y testeado (Fase 10).** El Coach Decision Engine
(`CoachDecisionEngine`) se testea explícitamente para que, ante datos
estables o cambios menores, la decisión más frecuente sea "no intervenir".
`testCoachDecisionEngineSpeaksSparinglyAcrossFullRun` corre el escenario
completo de referencia (1200 muestras de FC) y verifica que el número de
intervenciones se mantenga ≤ 3 en 20 minutos de simulación — no una por
cada muestra.

Durante la implementación, este mismo test atrapó un bug real: la
deduplicación comparaba eventos por igualdad estricta (incluyendo el BPM
exacto, que cambia en casi cada muestra), así que nunca detectaba que "ya
había dicho esto" y hablaba 10 veces en vez de 2-3. Corregido comparando
por `CoachEvent.kind` en vez de por el evento completo — ver
[docs/decisions.md](decisions.md) para el detalle. Es el ejemplo más claro
hasta ahora de por qué vale la pena tener un test de escenario completo,
no solo tests unitarios aislados.

## Estado actual

**Fase 10 completada.** 59 tests en verde (`swift test`) en `RunCoachCore`,
cubriendo:

- Fases 2-3: modelos, métricas, `RunState`, Simulation Engine (40 tests).
- Fase 6: `HeartRateMeasurementParser` — parsing GATT del Heart Rate
  Service, sin CoreBluetooth (8 tests).
- Fase 10: `CoachEventDetector` y `CoachDecisionEngine` — detección de
  eventos, deduplicación, cooldown, contexto reciente, y el test de
  escenario completo descrito arriba (11 tests).

Explícitamente sin cubrir todavía (fases futuras): UI/integración iOS
(Fases 4-9, solo validadas por compilación en CI — ver PROJECT_STATUS.md),
pruebas con hardware real (Fases 14-18).

## Audio Coach: convivencia con música y salida de audio genérica (requisitos permanentes)

Ver [docs/audio-coach.md](audio-coach.md) para el diseño completo — dos
requisitos permanentes del producto: (1) convivencia con música de otras
apps vía ducking, no interrupción, y (2) independencia de AirPods —
funciona con cualquier salida de audio que iOS tenga activa. Es lógica
exclusiva de `AVAudioSession`/`AVSpeechSynthesizer` (Apple), así que no
agrega tests a `RunCoachCore` — sigue en 93 tests, sin cambios por este
trabajo. La validación real vive en la checklist ampliada de
`docs/audio-coach.md`: Spotify/YouTube Music/Apple Music, AirPods,
auriculares Bluetooth de otra marca, altavoz del iPhone, desconexión/
reconexión de auriculares en plena carrera, cambio entre dos salidas
Bluetooth, interrupciones, pantalla bloqueada, y varias intervenciones
seguidas — pendiente de hardware real, mismo estado que el resto de
BLE/GPS/Audio.
