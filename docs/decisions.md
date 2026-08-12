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

---

## 2026-08-11 — `HeartRateSource`/`LocationSource` con closures, no Combine

**Decisión**: las abstracciones de fuente de datos en `RunCoachCore` usan
un closure simple (`onSample: ((Sample) -> Void)?`) en vez de
`AnyPublisher` de Combine, como se había esbozado inicialmente en
[docs/architecture.md](architecture.md).

**Motivo**: Combine es exclusivo de plataformas Apple y no está disponible
en el toolchain de Swift para Windows/Linux. Usarlo hubiera roto el
objetivo central de que `RunCoachCore` se compile y testee en Windows.

**Alternativas consideradas**: ninguna — es un requisito duro de
portabilidad, no una preferencia de estilo.

---

## 2026-08-11 — Timestamps como `TimeInterval` relativo, no `Date`

**Decisión**: `HeartRateSample.timestamp` y `LocationSample.timestamp` son
`TimeInterval` (segundos transcurridos desde el inicio de la carrera), no
`Date`.

**Motivo**: hace que `RunState` sea determinista y trivial de testear con
datos sintéticos (sin mockear el reloj del sistema), y es exactamente lo
que el Simulation Engine (Fase 3) va a necesitar para controlar la
progresión del tiempo de forma reproducible (ver
[docs/testing.md](testing.md)).

**Alternativas consideradas**: `Date` — descartado porque acopla los tests
al reloj real y complica la simulación determinista.

---

## 2026-08-11 — Bundle ID `com.vicente.runcoach` como placeholder

**Decisión**: usar `com.vicente.runcoach` como `PRODUCT_BUNDLE_IDENTIFIER`
en `RunCoach-iOS/project.yml`.

**Motivo**: hace falta *algún* bundle ID válido para que el proyecto
compile, pero todavía no existe una cuenta de Apple Developer (esa es la
Fase 12) que determine el identificador real/definitivo. Es un valor
trivial de cambiar más adelante (una línea en `project.yml`), así que no
se bloqueó la Fase 4 por esto.

**Impacto**: cuando se cree la cuenta de Apple Developer (Fase 12), hay que
revisar este valor contra el identificador real registrado ahí antes de
intentar firmar o subir a TestFlight.

---

## 2026-08-11 — Fase 4: build de CI sin firma (solo simulador)

**Decisión**: el primer workflow de Codemagic (`codemagic.yaml`) compila
para `generic/platform=iOS Simulator` con `CODE_SIGNING_ALLOWED=NO`, sin
firma, sin provisioning profile, sin publishing.

**Motivo**: todavía no hay cuenta de Apple Developer ni certificados (Fase
12). El objetivo de Fase 4 es validar que el proyecto compila en CI sin
depender de una Mac local — no requiere firma para eso. Firmar y subir a
TestFlight se agrega recién en las Fases 12-13, cuando haya con qué firmar.

**Alternativas consideradas**: ninguna — firmar sin certificados no es
posible, así que no había otra opción real para Fase 4.

---

## 2026-08-11 — Fix: `info.path` es obligatorio en `project.yml`

**Qué pasó**: el primer build real en Codemagic falló en el paso
`xcodegen generate` con `Parsing project spec failed: Decoding failed at
"path": Nothing found`. `project.yml` tenía `info.properties` sin
`info.path` — asumí que XcodeGen podía generar el Info.plist "en memoria"
sin necesidad de indicar dónde, pero el campo `path` es obligatorio para
cualquier objeto Plist en el spec, aunque el archivo todavía no exista
(XcodeGen lo crea ahí). No se pudo detectar este error antes porque
`xcodegen` no corre en Windows — la primera vez que se pudo probar de
verdad fue en el build de Codemagic.

**Fix**: agregar `info.path: App/Info.plist` en
[RunCoach-iOS/project.yml](../RunCoach-iOS/project.yml). XcodeGen genera el
archivo ahí a partir de `properties` en el próximo `xcodegen generate`.

**Impacto en el proceso**: confirma que hay una clase de errores de
`project.yml`/`codemagic.yaml` que solo se detectan corriendo el build real
en CI, no antes — al iterar sobre esto, esperar 1-2 vueltas más de este
mismo patrón (fallo en CI → leer log → fix → commit → nuevo build) es
normal, no señal de que el diseño esté mal.
