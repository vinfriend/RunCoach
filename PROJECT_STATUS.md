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
**Fase 5** (UI SwiftUI) — **completada**.
**Fase 6** (BLE) — **completada** (en el sentido de "compila"). Build de
Codemagic para el commit `a7b6e40` terminó `finished` sin pasos fallidos
(1m 9s). La parte de parsing (`HeartRateMeasurementParser`) está validada
de verdad: 8 tests nuevos en verde en Windows. La parte de CoreBluetooth
(`BLEHeartRateSource`) solo está validada por compilación — **ni siquiera
el simulador de iOS sirve para probar BLE real**, así que sigue
funcionalmente sin verificar hasta tener hardware real (Fase 14).
**Fase 7** (GPS) — **completada** (en el sentido de "compila"). Build de
Codemagic para el commit `f4d289b` terminó `finished` sin pasos fallidos
(1m 2s). `GPSLocationSource` (CoreLocation) sigue el mismo patrón que
Fase 6: válido solo por compilación de mi lado (sin Mac). A diferencia de
BLE, el simulador de iOS sí soporta simular ubicación — pero sin Mac para
abrir Xcode, la diferencia práctica con Fase 6 es nula por ahora.

Nota de proceso (desde Fase 5): el trigger automático por `push` de
Codemagic no está disparando solo — hay que iniciar el build a mano desde
el dashboard ("Start new build") cada vez.

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

**48 tests, 0 fallas**, en `RunCoachCore` (40 de Fases 2-3 + 8 nuevos de
`HeartRateMeasurementParserTests` en Fase 6). Es la primera vez que una
fase "de hardware" deja algo realmente testeado en Windows — separar el
parsing GATT (portable) de CoreBluetooth (no portable) fue justo para
lograr esto.

## Build iOS

**Fases 4 a 7 validadas en CI real** (todos los builds verdes). Para
Fase 6/7 en general: un build verde solo confirma que el código compila
contra las APIs de CoreBluetooth/CoreLocation — no que funcione con
hardware/GPS real.

### Qué se agregó en Fase 6

- `RunCoachCore/Sources/RunCoachCore/BLE/HeartRateMeasurementParser.swift`:
  decodifica el payload de la característica Heart Rate Measurement
  (`0x2A37`) según la spec del Bluetooth SIG (formato UINT8/UINT16,
  ignorando energy expended/RR-interval). Lógica pura, sin CoreBluetooth
  — testeada en Windows.
- `RunCoach-iOS/App/BLE/BLEHeartRateSource.swift`: implementa
  `HeartRateSource` con `CBCentralManager`/`CBPeripheral`. Escanea el
  servicio `0x180D`, conecta, se suscribe a notificaciones de `0x2A37`,
  reconecta automáticamente ante desconexión. Usa
  `HeartRateMeasurementParser` para decodificar cada valor.

### Qué NO se hizo en Fase 6 (a propósito)

- No se wireó `BLEHeartRateSource` a la UI (`RunView`) — eso es Fase 8
  ("Run Data Engine completo"), cuando se reemplace la simulación por
  fuentes reales de verdad.
- No hay manejo elaborado de errores/estados de Bluetooth (apagado, sin
  permisos) más allá de lo mínimo — no tiene sentido afinar eso sin poder
  probarlo con hardware real.
- No hay soporte para múltiples sensores ni selección manual — se conecta
  al primero que encuentre exponiendo el servicio estándar.

### Qué se agregó en Fase 7

- `RunCoach-iOS/App/GPS/GPSLocationSource.swift`: implementa
  `LocationSource` con `CLLocationManager`. Pide autorización "When In
  Use" (no "Always" — eso es Fase 15), `activityType: .fitness`,
  `pausesLocationUpdatesAutomatically: false`. Convierte cada
  `CLLocation` a un `LocationSample` con timestamp relativo a un `Date`
  de referencia fijado en `start()` (mismo patrón que Fase 6).

### Qué NO se hizo en Fase 7 (a propósito)

- No se pide autorización "Always" ni se valida background tracking real
  — eso es explícitamente la Fase 15 del roadmap.
- No se wireó a la UI — Fase 8, igual que BLE.
- Sin manejo elaborado de errores (`didFailWithError` vacío por ahora) —
  mismo criterio que en Fase 6: afinar con datos reales tiene más sentido
  que adivinar sin ellos.

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
14. Timestamp de `BLEHeartRateSource` calculado contra un `Date` de
    referencia fijado en `start()` — a revisar en Fase 8 si todas las
    fuentes deben compartir un único punto de referencia.
15. `GPSLocationSource` solo pide autorización "When In Use" — "Always" y
    la validación de background real quedan para Fase 15.

## Arquitectura

Resumen en [docs/architecture.md](docs/architecture.md). Fase 6 reforzó el
patrón "todo lo que sea lógica pura va en RunCoachCore, aunque esté
relacionado con BLE" — no todo lo que toca hardware es automáticamente
código de plataforma.

## Hardware

Sin cambios respecto a Fase 1 en cuanto a investigación. Ver
[docs/hardware.md](docs/hardware.md). Sin compras realizadas.
`BLEHeartRateSource` implementa el protocolo estándar investigado ahí,
pero sigue sin validarse con ningún sensor real.

## Riesgos identificados

Ver tabla completa en [docs/architecture.md](docs/architecture.md#riesgos-identificados-fase-1).
`BLEHeartRateSource` (Fase 6) y ahora `GPSLocationSource` (Fase 7) son
código que no se pudo ejercitar de ninguna forma de mi lado — ni Windows,
ni siquiera el simulador de iOS (para GPS en teoría sí se podría, pero sin
Mac para abrir Xcode da lo mismo). El riesgo de "código nunca antes
corrido" se mantiene hasta las Fases 14-15.

## Archivos creados (nuevos en Fase 7)

```
RunCoach-iOS/App/GPS/GPSLocationSource.swift
```

## Git

Repo en GitHub: [github.com/vinfriend/RunCoach](https://github.com/vinfriend/RunCoach),
`main` en sync con `origin/main`. Codemagic conectado.

## Próxima tarea

Esperar "Continuar con Fase 8" (Run Data Engine completo) de Vicente — ahí
es cuando `BLEHeartRateSource` y `GPSLocationSource` finalmente se
conectan a la UI, reemplazando la simulación para carreras reales.
