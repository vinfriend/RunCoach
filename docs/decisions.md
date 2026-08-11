# Decisiones de arquitectura (ADR ligero)

Formato: fecha, decisión, motivo, alternativas consideradas. Se agrega una
entrada nueva cada vez que se toma o se cambia una decisión técnica
relevante — en particular, cualquier cambio respecto al roadmap o
herramientas mencionadas en el prompt original de Vicente debe registrarse
acá.

---

## 2026-08-11 — Swift toolchain oficial de swift.org para Windows

**Decisión**: usar el toolchain oficial `Swift.Toolchain` (winget) para
compilar y testear `RunCoachCore` en Windows.

**Motivo**: es la distribución oficial mantenida por swift.org con soporte
first-class para Windows x64, instalable de forma no interactiva y segura
vía winget.

**Alternativas consideradas**: WSL2 con Swift para Linux — descartado por
ahora porque el toolchain nativo de Windows evita la capa de virtualización
y es más simple para este proyecto; se puede reconsiderar si aparecen
problemas de compatibilidad.

---

## 2026-08-11 — Codemagic como CI macOS remoto

**Decisión**: usar Codemagic para compilar `RunCoach-iOS` sin Mac local.

**Motivo**: free tier de 500 min/mes de build macOS, configuración
declarativa (`codemagic.yaml`), soporte directo para firma y TestFlight.

**Alternativas consideradas**: GitHub Actions con runners macOS (más caro
por minuto y sin las facilidades de firma/TestFlight integradas de
Codemagic), Mac en la nube alquilada por hora (MacStadium, etc. — más
complejidad operativa para un proyecto personal). Se documentará acá si se
cambia de proveedor.

---

## 2026-08-11 — XcodeGen para el proyecto Xcode

**Decisión**: generar `RunCoach-iOS.xcodeproj` desde un `project.yml`
declarativo con XcodeGen, no versionar el `.xcodeproj` a mano.

**Motivo**: sin Mac local, editar un `.xcodeproj` a mano es frágil y propenso
a conflictos de merge/corrupción. XcodeGen es más simple que Tuist para el
tamaño actual del proyecto.

**Alternativas consideradas**: Tuist (más funciones — caché, scaffolding —
pero generación más lenta y mayor complejidad; se reconsiderará si el
proyecto crece en número de módulos/targets).

---

## 2026-08-11 — WHOOP validado como fuente HR viable (con matiz)

**Decisión**: no descartar WHOOP de entrada; documentar que soporta el
Bluetooth Heart Rate Service estándar (0x180D) siempre que se active "HR
Broadcast" en su app.

**Motivo**: contradice la suposición inicial de "no asumas que WHOOP sirve"
— la investigación (Fase 1) muestra que sí cumple el perfil estándar. Sigue
sin comprarse/asumirse nada sin probarlo en la práctica en Fase 6/14. Ver
[docs/hardware.md](hardware.md).

**Alternativas consideradas**: Polar Verity Sense, Scosche Rhythm24 (ambos
brazaletes sin pantalla, perfil BLE HR estándar nativo sin necesidad de
activar nada) — quedan como plan B si WHOOP no resulta suficiente en la
práctica.

---

## 2026-08-11 — Visual Studio Build Tools + Windows SDK requeridos por Swift en Windows

**Decisión**: instalar `Microsoft.VisualStudio.2022.BuildTools` (componentes
`VC.Tools.x86.x64` + `Windows11SDK.22621`) además del toolchain de Swift, y
crear [`scripts/setup-swift-env.ps1`](../scripts/setup-swift-env.ps1) para
cargar las variables de entorno necesarias (VS dev env + `SDKROOT`) en cada
sesión de PowerShell nueva.

**Motivo**: `swift build`/`swift test` en Windows fallan con `unable to load
standard library for target 'x86_64-unknown-windows-msvc'` sin el linker
MSVC (`link.exe`) y las cabeceras/libs del Windows SDK, y sin `SDKROOT`
apuntando al SDK que trae el propio toolchain de Swift
(`Platforms\<version>\Windows.platform\Developer\SDKs\Windows.sdk`). No es
opcional: es un requisito documentado del toolchain oficial de swift.org
para Windows, no específico de este proyecto.

**Impacto**: cualquier sesión nueva (Claude Code o Vicente) que abra una
terminal para trabajar en `RunCoachCore` debe correr primero
`. .\scripts\setup-swift-env.ps1` (ver
[docs/windows-development.md](windows-development.md)). Documentado ahí en
detalle para no perder tiempo re-diagnosticando esto.
