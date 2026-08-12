# PROJECT_STATUS.md — fuente de verdad del progreso

> Leer esto (junto con [CLAUDE.md](CLAUDE.md)) antes de empezar cualquier
> sesión nueva. Ver también `git status` y `git log --oneline` para el
> estado exacto del código.

## Fase actual

**Fase 0** (entorno Windows) — **completada**.
**Fase 1** (arquitectura/investigación) — **completada**.
**Fase 2** (RunCoachCore: modelos, métricas, `RunState`) — **completada**.
**Fase 3** (Simulation Engine) — **completada**.
**Fase 4** (Proyecto iOS + CI macOS) — **parcialmente completada, bloqueada
en la parte que requiere a Vicente** (ver "Bloqueos" abajo).

Lo que se podía hacer sin intervención de Vicente ya está hecho:
`project.yml`, skeleton de la app iOS, `codemagic.yaml`. Falta: crear el
repo en GitHub, conectar Codemagic, y correr el build real en CI — eso
necesita login/autorización de Vicente.

## Último commit estable

Ver `git log --oneline -1` para el hash exacto. Incluye Fase 0 a Fase 4
(la parte de Fase 4 que no requiere GitHub/Codemagic).

## Bloqueos

- **Repo en GitHub**: no existe todavía. Necesita que Vicente cree el repo
  y/o autorice `gh auth login` (OAuth) — no es algo que se pueda hacer sin
  su intervención. Ver instrucciones exactas al final de este documento /
  en la respuesta de esta sesión.
- **Cuenta de Codemagic**: no existe todavía. Necesita que Vicente se
  registre (típicamente con "Sign in with GitHub", requiere el repo ya
  creado) y autorice el acceso al repo.
- **`codemagic.yaml` sin validar en CI**: como no hay Mac local, este
  archivo no se pudo ejecutar ni probar antes de escribirlo — su primera
  ejecución real va a ser en Codemagic una vez conectado. Si falla al
  primer intento, es información nueva a corregir, no necesariamente un
  error de diseño.

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

**Preparado, sin ejecutar todavía.** Existe:

- `RunCoach-iOS/project.yml` (XcodeGen): target `RunCoach`, dependencia
  local a `RunCoachCore`, `deploymentTarget: 16.0`, permisos de ubicación/
  Bluetooth/background modes declarados (placeholders para Fases 6-9).
- `RunCoach-iOS/App/RunCoachApp.swift` + `ContentView.swift`: skeleton
  mínimo de SwiftUI que instancia un `RunState()` de `RunCoachCore` — solo
  para probar la integración del paquete, no es la UI real (Fase 5).
- `RunCoach-iOS/Resources/Assets.xcassets/`: catálogo de assets mínimo con
  un slot de `AppIcon` vacío (sin imagen todavía).
- `codemagic.yaml` (raíz del repo): workflow `runcoach-ios-unsigned-build`
  — instala XcodeGen, genera el proyecto, compila para iOS Simulator sin
  firma (`CODE_SIGNING_ALLOWED=NO`). Sin publishing (no hay Apple Developer
  account, eso es Fase 12).

**Nada de esto se pudo validar realmente** porque no hay Mac local ni
Codemagic conectado — la primera corrida real de CI queda pendiente de que
Vicente complete las acciones de "Bloqueos".

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
Nuevo en Fase 4: el `codemagic.yaml` no pudo probarse antes de escribirse
(sin Mac local) — es esperable necesitar 1-2 iteraciones una vez que corra
en CI de verdad.

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

Repo local con commits de Fase 0/1, Fase 2, Fase 3 y Fase 4. **Sin remoto
en GitHub todavía** — es exactamente el bloqueo de esta fase.

## Próxima tarea

**Necesito una acción tuya para poder seguir con Fase 4** (crear el repo en
GitHub y conectar Codemagic). Ver el mensaje de esta sesión para los pasos
exactos. Una vez que:

1. el repo esté en GitHub con este código pusheado, y
2. Codemagic esté conectado a ese repo,

le aviso para correr el primer build y corregir lo que haga falta. Recién
ahí Fase 4 queda completa de verdad, y ahí sí espero tu "Continuar con Fase
5" antes de tocar la UI real de SwiftUI.
