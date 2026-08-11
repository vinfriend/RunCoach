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

Este escenario se implementa como un caso de test en Fase 3 y sirve como
"golden path" para validar el Coach Decision Engine: se espera que NO hable
en los primeros minutos, y que sí genere como máximo una intervención
relevante alrededor del minuto 15.

## Criterio de "no hablar por defecto"

El Coach Decision Engine se testea explícitamente para que, ante datos
estables o cambios menores, la decisión más frecuente sea "no intervenir".
Un test de regresión debe verificar que, para el escenario completo de
referencia, el número de intervenciones generadas se mantenga bajo (por
ejemplo, ≤ 2-3 en 20 minutos de simulación), no una por cada muestra.

## Estado actual

Fase 0: solo existe un test placeholder (`RunCoachCoreTests.swift`) que
valida que el toolchain de Swift compila y corre tests en Windows. Los tests
reales de dominio y del Simulation Engine se escriben en las Fases 2 y 3.
