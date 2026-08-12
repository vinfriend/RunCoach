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

**Fases 4, 5 y 6 validadas en CI real** (builds verdes). Para Fase 6 en
particular: el build verde solo confirma que `BLEHeartRateSource` compila
contra las APIs de CoreBluetooth — no que funcione con un sensor real,
algo que no se puede probar sin hardware (Fase 14) ni en el simulador de
iOS (no tiene radio Bluetooth).

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
Nuevo en Fase 6: `BLEHeartRateSource` es el primer código que ni siquiera
el simulador de iOS puede ejercitar — el riesgo de "código nunca antes
corrido" es mayor acá que en Fases 4-5. Mitigado parcialmente separando
el parsing (sí testeado) del transporte BLE (no testeable hasta Fase 14).

## Archivos creados (nuevos en Fase 6)

```
RunCoachCore/Sources/RunCoachCore/BLE/HeartRateMeasurementParser.swift
RunCoachCore/Tests/RunCoachCoreTests/HeartRateMeasurementParserTests.swift
RunCoach-iOS/App/BLE/BLEHeartRateSource.swift
```

## Git

Repo en GitHub: [github.com/vinfriend/RunCoach](https://github.com/vinfriend/RunCoach),
`main` en sync con `origin/main`. Codemagic conectado.

## Próxima tarea

Esperar "Continuar con Fase 7" (GPS) de Vicente. Recordar que, igual que
BLE, GPS real (`CoreLocation`) tampoco se va a poder probar de verdad sin
un iPhone (el simulador de iOS sí puede simular ubicación, a diferencia de
Bluetooth, así que Fase 7 debería ser algo más verificable que Fase 6 —
a confirmar cuando se llegue ahí).
