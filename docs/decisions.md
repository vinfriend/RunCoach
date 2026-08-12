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

---

## 2026-08-11 — Fase 5: pacing en tiempo real vive en RunCoach-iOS, no en RunCoachCore

**Decisión**: `RunSessionViewModel` (en `RunCoach-iOS/App/ViewModels/`)
reproduce el escenario simulado con `DispatchQueue.main.asyncAfter`,
acelerado 20x por defecto, envolviendo `RunState` +
`ScenarioSimulator.generate*Samples` de `RunCoachCore` sin modificarlos.

**Motivo**: `MockHeartRateSource`/`MockLocationSource` (Fase 3) reproducen
todas las muestras de forma síncrona e inmediata a propósito — es lo que
necesitan los tests deterministas. Para que la pantalla de carrera tenga
sentido visualmente (ver los números cambiar en el tiempo), hace falta
pacing real, pero eso usa `DispatchQueue`, que no existe en Windows/Linux.
Meterlo en `RunCoachCore` hubiera roto la portabilidad a Windows sin
necesidad — el pacing es una preocupación de la capa de presentación, no
del motor de dominio.

**Impacto**: cuando lleguen las fuentes reales (BLE Fase 6, GPS Fase 7),
`RunSessionViewModel` se puede adaptar para consumirlas en vez del
escenario simulado, sin tocar `RunCoachCore` — es exactamente el punto de
la abstracción `HeartRateSource`/`LocationSource`.

**Limitación conocida**: este código (como todo `RunCoach-iOS`) no se pudo
compilar ni ejecutar localmente — no hay Mac. Se valida únicamente vía el
build de Codemagic (compila para simulador, no corre la UI). Ver
PROJECT_STATUS.md para el resultado real una vez que corra en CI.

---

## 2026-08-11 — Fase 6: parsing GATT en RunCoachCore, CoreBluetooth en RunCoach-iOS

**Decisión**: `HeartRateMeasurementParser` (decodifica el payload de la
característica Heart Rate Measurement `0x2A37` según la spec del Bluetooth
SIG) vive en `RunCoachCore`, no en `RunCoach-iOS`. `BLEHeartRateSource`
(que sí usa `CBCentralManager`/`CBPeripheral`) vive en `RunCoach-iOS` y
llama al parser de `RunCoachCore`.

**Motivo**: decodificar bytes según un formato binario documentado es
lógica pura, sin ninguna dependencia de CoreBluetooth — exactamente el
tipo de cosa que puede (y debe) testearse en Windows con datos sintéticos,
en vez de quedar bloqueada hasta tener hardware real (Fase 14). Separar
"cómo hablarle a CoreBluetooth" de "cómo interpretar los bytes que llegan"
resultó en la mayor parte de la lógica de Fase 6 siendo testeable de
verdad (8 tests nuevos en Windows), y solo la cáscara de conexión BLE
queda sin poder probarse hasta Fase 14.

**Alternativas consideradas**: poner todo el parsing dentro de
`BLEHeartRateSource` en `RunCoach-iOS` — descartado porque hubiera dejado
esa lógica sin ningún test hasta tener un sensor físico, sin necesidad.

---

## 2026-08-11 — Fase 6: timestamp relativo vía `Date` de referencia

**Decisión**: `BLEHeartRateSource` guarda un `referenceStartDate = Date()`
al llamar `start()`, y calcula el `timestamp` de cada `HeartRateSample`
como `Date().timeIntervalSince(referenceStartDate)`.

**Motivo**: `HeartRateSample.timestamp` es un `TimeInterval` relativo al
inicio de la carrera (decisión de Fase 2), pensado para que
`ScenarioSimulator` genere datos deterministas sin usar el reloj real. Una
fuente real como `BLEHeartRateSource` sí vive en tiempo real, así que
necesita un punto de referencia contra el cual medir — se fija en el
momento en que arranca (`start()`), que es cuando lógicamente arranca la
carrera desde el punto de vista de esta fuente.

**Impacto futuro**: cuando se wireé el pipeline completo (Fase 8), hay que
decidir si todas las fuentes (BLE, GPS) comparten un único
`referenceStartDate` fijado por quien orquesta la carrera, en vez de que
cada fuente tenga el suyo — probablemente sí, para que los timestamps de
HR y GPS sean comparables entre sí. Queda para Fase 8, no se resuelve acá.

**Sin validar con hardware real.** Como el resto de Fase 6, esto es una
decisión de diseño razonada, no confirmada empíricamente — no hay forma de
confirmarla sin un sensor real (Fase 14).

---

## 2026-08-11 — Fase 7: solo autorización "When In Use", "Always" queda para Fase 15

**Decisión**: `GPSLocationSource` pide únicamente
`requestWhenInUseAuthorization()`. No pide `requestAlwaysAuthorization()`
en esta fase.

**Motivo**: el roadmap separa Fase 7 ("GPS") de Fase 15 ("GPS/background
real") a propósito. Pedir "Always" tiene sentido recién cuando se pueda
mostrarle al usuario por qué hace falta (patrón recomendado por Apple:
pedir "When In Use" primero, mostrar valor, pedir "Always" después con un
motivo concreto) y cuando haya forma de probar que el tracking en
background realmente sobrevive — nada de eso existe todavía. El código
deja el terreno preparado (`allowsBackgroundLocationUpdates` condicionado
a que la autorización ya sea "Always") sin forzar el flujo completo.

**Impacto**: mientras no se pida "Always", el tracking en background real
(con la pantalla bloqueada) no va a funcionar — es exactamente el
comportamiento esperado hasta Fase 15, no un bug.

**A diferencia de BLE (Fase 6)**: el simulador de iOS sí puede simular
ubicación (Debug > Simulate Location en Xcode), así que en teoría esta
fase es más verificable que la anterior — pero sin Mac para abrir Xcode,
la diferencia práctica es nula por ahora. Documentado para que quede claro
que la limitación actual es "no tenemos Mac", no "CoreLocation no se puede
probar nunca sin hardware" (que sí sería el caso de BLE).

---

## 2026-08-11 — Fase 8: `referenceStartDate` inyectable en las fuentes reales

**Decisión**: `BLEHeartRateSource.referenceStartDate` y
`GPSLocationSource.referenceStartDate` pasan de fijarse solos con
`Date()` dentro de `start()` a ser propiedades públicas settable, con
`Date()` como valor por defecto (útil para uso standalone). Quien
coordina una carrera real (`RunSessionViewModel.startReal()`, Fase 8) crea
un único `Date()` y se lo asigna a **ambas** fuentes antes de arrancarlas.

**Motivo**: esta era exactamente la nota pendiente dejada en la decisión
de Fase 6 ("timestamp de BLEHeartRateSource... a revisar en Fase 8 si
todas las fuentes deben compartir un único punto de referencia"). Sin
esto, si `BLEHeartRateSource` y `GPSLocationSource` fijan cada una su
propio `Date()` en momentos ligeramente distintos (por ejemplo,
`GPSLocationSource` puede arrancar de inmediato pero `BLEHeartRateSource`
espera a que `CBCentralManager` esté `poweredOn`), sus timestamps
relativos quedarían desalineados entre sí — un problema real para
`RunState`, que asume que los timestamps de FC y de GPS son comparables
en la misma línea de tiempo.

**Impacto**: `isRunning` (bool interno) reemplaza a "`referenceStartDate
!= nil`" como flag de "¿estoy corriendo?" en ambas clases, ya que
`referenceStartDate` ahora siempre tiene un valor (no es opcional).

**Sin validar con hardware real** — como el resto de Fases 6-8, esto es
una corrección de diseño razonada a partir de cómo funcionan las APIs
documentadas, no confirmada empíricamente.

---

## 2026-08-11 — Fase 9: anuncios mecánicos, no Coach Decision Engine

**Decisión**: `AudioCoach` (Fase 9) es pura infraestructura de voz —
recibe un `String` y lo dice, sin ninguna lógica propia. Las llamadas a
`speak(_:)` desde `RunSessionViewModel` están atadas a eventos mecánicos y
deterministas que `RunCoachCore` ya calcula: inicio de carrera, fin de
carrera, cada split completado (con su ritmo). No hay prioridades,
cooldown, deduplicación, ni ningún juicio sobre "¿esto vale la pena
decirlo ahora?".

**Motivo**: el roadmap separa explícitamente Fase 9 ("Audio Coach" — que
la app pueda hablar) de Fase 10 ("Coach Decision Engine" — cuándo y qué
debería decir). Meter lógica de decisión acá hubiera mezclado dos
responsabilidades distintas antes de tiempo. El requisito del prompt
original también es explícito: "Primero quiero que el coach me hable" —
sin exigir que sea inteligente todavía.

**Impacto**: los anuncios actuales (split completado, inicio/fin) son
deliberadamente simples y van a seguir sonando incluso después de que
exista el Coach Decision Engine — la diferencia es que Fase 10 va a
agregar anuncios *adicionales* basados en tendencias/eventos, con su
propia lógica de cuándo callarse.

**Voz en español (`es-AR`)**: coherente con que todo el proyecto y la
documentación están en español y el usuario es de Argentina. Configurable
vía el parámetro `languageCode` de `AudioCoach.init` si hace falta
cambiarlo más adelante.

**`AVAudioSession` con `.duckOthers`**: para que el coach pueda hablar
sobre música/podcast sin cortarlo del todo — baja el volumen mientras
habla y lo restaura después, comportamiento estándar de apps de fitness
con voz.

**Sin validar con audio real** — a diferencia de BLE, el simulador de iOS
sí reproduce audio, así que en teoría esto se podría escuchar sin
hardware — pero seguimos sin Mac para abrir Xcode y probarlo.
