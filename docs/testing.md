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

Este escenario sirve como "golden path" para validar, más adelante, el
Coach Decision Engine (Fase 10): se espera que NO hable en los primeros
minutos, y que sí genere como máximo una intervención relevante alrededor
del minuto 15 — eso todavía no está implementado ni testeado, porque el
Coach Decision Engine es una fase aparte.

## Criterio de "no hablar por defecto"

El Coach Decision Engine se testea explícitamente para que, ante datos
estables o cambios menores, la decisión más frecuente sea "no intervenir".
Un test de regresión debe verificar que, para el escenario completo de
referencia, el número de intervenciones generadas se mantenga bajo (por
ejemplo, ≤ 2-3 en 20 minutos de simulación), no una por cada muestra.

## Estado actual

**Fase 3 completada.** 40 tests en verde (`swift test`), cubriendo:

- Fase 2: modelos, métricas (`MovingAverage`, `GeoDistance`,
  `HeartRateTrend`), y `RunState` (splits, distancia, ritmo, tendencia).
- Fase 3: interpolación de segmentos (`ScenarioSegmentTests`), generación
  determinista de muestras incluyendo pérdida de señal y anomalías
  (`ScenarioSimulatorTests`), reproducción de fuentes simuladas
  (`MockSourceTests`), y el escenario de referencia de 20 minutos de punta
  a punta (`ReferenceScenarioTests`).

Explícitamente sin cubrir todavía (fases futuras): Coach Decision Engine
(Fase 10), UI/integración iOS (Fase 5+), pruebas con hardware real (Fases
17-18).
