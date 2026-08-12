# PROJECT_STATUS.md — fuente de verdad del progreso

> Leer esto (junto con [CLAUDE.md](CLAUDE.md)) antes de empezar cualquier
> sesión nueva. Ver también `git status` y `git log --oneline` para el
> estado exacto del código.

## Fase actual

**Fase 0** (entorno Windows) — **completada**.
**Fase 1** (arquitectura/investigación) — **completada**.
**Fase 2** (RunCoachCore: modelos, métricas, `RunState`) — **completada**.
**Fase 3** (Simulation Engine) — **completada**.
**Fase 4** (Proyecto iOS + CI macOS) — **completada**. Primer build real
en Codemagic (`runcoach-ios-unsigned-build`, commit `dfa3980`) terminó en
verde: `Status: finished`, todos los pasos OK, sin ningún paso en rojo
(build de 1m 12s). El proyecto compila en CI sin depender de una Mac
local — objetivo central de esta fase, cumplido.

## Último commit estable

Ver `git log --oneline -1` para el hash exacto. Incluye Fase 0 a Fase 4
completas.

## Bloqueos

Ninguno activo. Los dos de Fase 4 (repo en GitHub, cuenta de Codemagic)
quedaron resueltos por Vicente.

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
| GitHub CLI (`gh`) | **Instalado** (Fase 4) — sin autenticar todavía (`gh auth login` pendiente, acción de Vicente) |
| Docker | No instalado — no requerido por ahora |

Detalle completo en [docs/windows-development.md](docs/windows-development.md).

## Tests en Windows

Sin cambios respecto a Fase 3: **40 tests, 0 fallas**, en `RunCoachCore`.
Fase 4 no agregó lógica a `RunCoachCore` — solo el proyecto iOS, que no se
puede testear en Windows (ver [docs/windows-development.md](docs/windows-development.md)).

## Build iOS

**Validado en CI real (Codemagic).** Existe:

- `RunCoach-iOS/project.yml` (XcodeGen): target `RunCoach`, dependencia
  local a `RunCoachCore`, `deploymentTarget: 16.0`, permisos de ubicación/
  Bluetooth/background modes declarados (placeholders para Fases 6-9).
  `info.path: App/Info.plist` — XcodeGen genera el Info.plist ahí (ver bug
  corregido abajo).
- `RunCoach-iOS/App/RunCoachApp.swift` + `ContentView.swift`: skeleton
  mínimo de SwiftUI que instancia un `RunState()` de `RunCoachCore` — solo
  para probar la integración del paquete, no es la UI real (Fase 5).
- `RunCoach-iOS/Resources/Assets.xcassets/`: catálogo de assets mínimo con
  un slot de `AppIcon` vacío (sin imagen todavía).
- `codemagic.yaml` (raíz del repo): workflow `runcoach-ios-unsigned-build`
  — instala XcodeGen, genera el proyecto, compila para iOS Simulator sin
  firma (`CODE_SIGNING_ALLOWED=NO`). Sin publishing (no hay Apple Developer
  account, eso es Fase 12).

**Bug real encontrado y corregido en el primer intento**: el build #1
falló en `xcodegen generate` con `Decoding failed at "path": Nothing
found` — `info.properties` sin `info.path` no es válido para XcodeGen (el
`path` del Plist es obligatorio aunque el archivo no exista todavía). Fix
de una línea (commit `dfa3980`), build #2 pasó limpio. Detalle en
[docs/decisions.md](docs/decisions.md).

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
9. Bundle ID `com.vicente.runcoach` como placeholder hasta que exista una
   cuenta de Apple Developer real (Fase 12).
10. Primer build de CI sin firma (solo simulador) — no hay certificados
    todavía, y no hacen falta para validar que el proyecto compila.

## Arquitectura

Resumen en [docs/architecture.md](docs/architecture.md). Sin cambios de
fondo en Fase 4 — se agregó el proyecto iOS concreto sobre el diseño ya
documentado (RunCoachCore portable + RunCoach-iOS específico de Apple).

## Hardware

Sin cambios respecto a Fase 1. Ver [docs/hardware.md](docs/hardware.md).
Sin compras realizadas.

## Riesgos identificados

Ver tabla completa en [docs/architecture.md](docs/architecture.md#riesgos-identificados-fase-1).
Confirmado en Fase 4: `project.yml`/`codemagic.yaml` sí necesitaron una
iteración de fix una vez corridos en CI de verdad (esperable, sin Mac local
para probarlos antes) — mitigado, no bloqueante.

## Archivos creados (nuevos en Fase 4)

```
codemagic.yaml
RunCoach-iOS/project.yml
RunCoach-iOS/App/RunCoachApp.swift
RunCoach-iOS/App/ContentView.swift
RunCoach-iOS/Resources/Assets.xcassets/Contents.json
RunCoach-iOS/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json
```

(Lista completa de archivos de fases anteriores sin cambios — ver el
historial de este documento en `git log -p PROJECT_STATUS.md` si hace
falta.)

## Git

Repo local con commits de Fase 0/1, Fase 2, Fase 3 y Fase 4, **pusheado a
GitHub**: [github.com/vinfriend/RunCoach](https://github.com/vinfriend/RunCoach)
(`main`, en sync con `origin/main`). Codemagic conectado y con build verde.

## Próxima tarea

Esperar confirmación explícita de Vicente ("Continuar con Fase 5") antes de
empezar la UI real de SwiftUI (pantalla de carrera, configuración,
historial) sobre el skeleton actual.
