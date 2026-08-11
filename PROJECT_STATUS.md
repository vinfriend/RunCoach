# PROJECT_STATUS.md — fuente de verdad del progreso

> Leer esto (junto con [CLAUDE.md](CLAUDE.md)) antes de empezar cualquier
> sesión nueva. Ver también `git status` y `git log --oneline` para el
> estado exacto del código.

## Fase actual

**Fase 0** (entorno Windows) — **completada**.
**Fase 1** (arquitectura/investigación) — **completada**.

Ambas quedan cerradas a la espera de que Vicente escriba "Continuar con
Fase 2" para empezar la implementación real de RunCoachCore.

## Último commit estable

Ver `git log --oneline -1` — primer commit del repo, incluye toda la
documentación, el scaffold de `RunCoachCore` y el script de entorno de
Windows.

## Entorno Windows

| Item | Estado |
|---|---|
| Windows 11 Home 10.0.26200, x64 | OK |
| AMD Ryzen AI 7 350, 8 núcleos/16 hilos, ~14GB RAM, ~334GB libres en C:\ | OK |
| Git 2.54.0 | OK, ya configurado |
| Swift toolchain 6.3.3 (swift.org, winget) | OK |
| Visual Studio 2022 Build Tools + Windows 11 SDK (10.0.22621.0) | OK — requerido por Swift para enlazar en Windows |
| VS Code 1.118.0 | OK |
| winget 1.29.280 | OK |
| GitHub CLI (`gh`) | No instalado — se instala en Fase 4 al conectar GitHub |
| Docker | No instalado — no requerido por ahora |

Detalle completo, incluyendo el setup de entorno necesario en cada terminal
nueva, en [docs/windows-development.md](docs/windows-development.md).

## Tests en Windows

**`swift build` y `swift test` corren en verde** en `RunCoachCore` (usando
`scripts/setup-swift-env.ps1` para cargar el entorno de VS + `SDKROOT`).
Por ahora solo existe un test placeholder (`RunCoachCoreTests.swift`) que
valida que el toolchain compila y corre — no hay lógica de dominio todavía
(eso es Fase 2).

## Build iOS

No iniciado. `RunCoach-iOS/` existe como carpeta vacía preparada para la
Fase 4 (Xcode project vía XcodeGen + CI en Codemagic). Sin Mac local, sin
cuenta de Codemagic creada todavía, sin repo en GitHub todavía.

## Decisiones tomadas

Ver [docs/decisions.md](docs/decisions.md) para el detalle y motivos:

1. Swift toolchain oficial de swift.org para Windows (no WSL2).
2. Visual Studio 2022 Build Tools + Windows 11 SDK, requeridos por Swift
   para enlazar en Windows; script `scripts/setup-swift-env.ps1` para
   cargar el entorno en cada terminal nueva.
3. Codemagic como CI macOS remoto (free tier 500 min/mes).
4. XcodeGen para generar el proyecto Xcode de forma declarativa (no Tuist,
   por simplicidad en esta etapa).
5. WHOOP validado como fuente HR viable (con matiz: requiere activar "HR
   Broadcast"); Polar Verity Sense / Scosche Rhythm24 como plan B.

## Arquitectura

Resumen en [docs/architecture.md](docs/architecture.md): RunCoachCore
(Swift Package portable, testeable en Windows) + RunCoach-iOS (SwiftUI/
CoreBluetooth/CoreLocation/AVFoundation, compilado solo en CI macOS). El
motor de carrera nunca depende de la red; OpenAI se consulta solo ante
eventos relevantes, de forma no bloqueante.

## Hardware

Investigación completada, **sin compras realizadas**. Resumen en
[docs/hardware.md](docs/hardware.md):

- WHOOP cumple el perfil BLE Heart Rate estándar (0x180D) si se activa "HR
  Broadcast" en su app — contradice la suposición inicial de descartarlo.
- Polar Verity Sense y Scosche Rhythm24 (brazaletes sin pantalla) lo cumplen
  nativamente, sin configuración adicional — quedan como plan B.
- Ninguna compra se recomienda ni se realiza hasta llegar a Fase 6/14 y
  validar en la práctica.

## Riesgos identificados

Ver tabla completa en [docs/architecture.md](docs/architecture.md#riesgos-identificados-fase-1).
Los principales: justificación de ubicación en background ante App Review,
verificación del perfil BLE antes de comprar hardware (ya mitigado por la
investigación), consumo de minutos de Codemagic, control de costo/latencia
de OpenAI (aún no aplica, Fase 11).

## Archivos creados

```
CLAUDE.md
PROJECT_STATUS.md
README.md
.gitignore
.github/workflows/runcoachcore-tests.yml
RunCoachCore/Package.swift
RunCoachCore/Sources/RunCoachCore/RunCoachCore.swift
RunCoachCore/Tests/RunCoachCoreTests/RunCoachCoreTests.swift
scripts/setup-swift-env.ps1
docs/architecture.md
docs/decisions.md
docs/hardware.md
docs/ios-build.md
docs/openai.md
docs/real-world-tests.md
docs/testing.md
docs/windows-development.md
```

## Git

Repo local inicializado (`main`), `.gitignore` configurado, primer commit
hecho. Sin remoto en GitHub todavía (se conecta en Fase 4).

## Próxima tarea

Esperar confirmación explícita de Vicente ("Continuar con Fase 2") antes de
empezar la implementación real de RunCoachCore: modelos de dominio
(`HeartRateSample`, `LocationSample`, `RunState`, `Split`), motor de
métricas (medias móviles, ritmo suavizado, splits), detección de tendencias/
eventos, y las primeras piezas del Coach Decision Engine — todo con tests
en Windows.
