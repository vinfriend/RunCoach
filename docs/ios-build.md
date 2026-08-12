# Build de iOS sin Mac local

## Flujo

```
Windows (edición, RunCoachCore) → GitHub (repo) → Codemagic (macOS cloud)
   → Xcode build/test/sign → App Store Connect → TestFlight → iPhone
```

## Por qué Codemagic

- Corre en máquinas macOS en la nube (Mac mini M2 al momento de esta
  investigación), no requiere Xcode ni Mac local.
- Free tier: **500 minutos de build macOS/mes** — suficiente para iterar en
  las primeras fases sin gastar nada.
- Pago por uso desde $0.045/min (Linux) o $0.095/min (Mac M2) si se supera el
  free tier; también hay planes anuales fijos, pero no son necesarios para
  un proyecto personal en esta etapa.
- Configuración declarativa vía `codemagic.yaml` en el repo (versionable,
  auditable, sin clicks perdidos en una UI).
- Soporta firma automática, provisioning profiles y subida directa a
  TestFlight/App Store Connect.

Se documentará aquí cualquier cambio de proveedor de CI si aparece una razón
técnica o económica claramente superior (ver regla en
[docs/decisions.md](decisions.md)).

## Por qué no versionar `.xcodeproj` a mano

Sin Xcode local es fácil que el `.xcodeproj` (formato binario/XML frágil,
pensado para editarse desde la UI de Xcode) se corrompa o diverja al
editarlo a mano o por script. En su lugar:

- **XcodeGen**: genera el `.xcodeproj` a partir de un `project.yml`
  declarativo (YAML) versionado en Git. Simple, rápido, mantenimiento
  comunitario activo aunque más lento que Tuist.
- Alternativa evaluada: **Tuist** (configuración en Swift, más funciones —
  caché, scaffolding, modularización) pero con generación más lenta y mayor
  complejidad. Para el tamaño actual del proyecto, XcodeGen es la opción más
  simple y suficiente.
- El `.xcodeproj` generado **no se commitea** (ver `.gitignore`); se genera
  en cada build, tanto local (si algún día hay Mac) como en CI.

## `project.yml` (Fase 4)

En [RunCoach-iOS/project.yml](../RunCoach-iOS/project.yml). Puntos clave:

- Target `RunCoach`, tipo `application`, `deploymentTarget: 16.0`.
- Dependencia local a `RunCoachCore` vía `packages: { RunCoachCore: { path: ../RunCoachCore } }`
  — el mismo Swift Package que se testea en Windows, sin duplicar código.
- `PRODUCT_BUNDLE_IDENTIFIER: com.vicente.runcoach` — **placeholder**, se
  ajusta cuando exista una cuenta de Apple Developer real (Fase 12); ver
  [docs/decisions.md](decisions.md).
- `Info.plist` generado inline (sin archivo separado) con los permisos que
  van a hacer falta en fases futuras (ubicación, Bluetooth, background
  modes) — declarados desde ya para no tener que reestructurar el target
  más adelante, aunque el código que realmente los use (BLE, GPS,
  background) todavía no existe.

## `codemagic.yaml` (Fase 4)

En la raíz del repo: [codemagic.yaml](../codemagic.yaml). Un solo workflow,
`runcoach-ios-unsigned-build`:

1. `brew install xcodegen` (la imagen de Codemagic no lo trae preinstalado).
2. `xcodegen generate` dentro de `RunCoach-iOS/` para generar el
   `.xcodeproj` a partir de `project.yml`.
3. `xcodebuild build` apuntando a `generic/platform=iOS Simulator` con
   `CODE_SIGNING_ALLOWED=NO`.

**A propósito, sin firma ni publishing todavía.** No hay cuenta de Apple
Developer (Fase 12) ni certificados — el objetivo de Fase 4 es únicamente
demostrar que el proyecto compila en CI sin depender de una Mac local.
Firma, provisioning profiles y subida a TestFlight se agregan al
`codemagic.yaml` cuando lleguemos a las Fases 12-13.

Como no hay Mac local, este workflow **no se pudo ejecutar ni validar
localmente** — su primera ejecución real va a ser en Codemagic, una vez que
el repo esté en GitHub y conectado (ver "Estado actual" abajo). Si falla,
es información nueva para corregir, no un fallo de la Fase 4.

## Estado actual

- Repo en GitHub: [github.com/vinfriend/RunCoach](https://github.com/vinfriend/RunCoach), `main` en sync.
- Cuenta de Codemagic: conectada al repo.
- `project.yml` / `codemagic.yaml`: **validados en CI real** — build
  `runcoach-ios-unsigned-build` en verde (commit `dfa3980`, 1m 12s).
- GitHub CLI (`gh`): instalado vía winget, sin autenticar en esta máquina
  (no hizo falta — el push se hizo por HTTPS con credenciales ya
  disponibles).

### Bug encontrado y corregido en el primer build

El primer intento falló en `xcodegen generate`:

```
Parsing project spec failed: Decoding failed at "path": Nothing found
```

Causa: el bloque `info:` de un target en `project.yml` requiere una
propiedad `path` (dónde generar el `Info.plist`), no alcanza con declarar
solo `properties`. Fix: agregar `info.path: App/Info.plist`. No se pudo
detectar esto antes de correr en CI porque `xcodegen` no corre en Windows —
es exactamente el tipo de fricción esperada al no tener Mac local, y quedó
resuelto en una sola iteración. Ver
[docs/decisions.md](decisions.md) para el detalle completo.

## Fase 12 — Apple Developer / firma

Primera fase gateada casi por completo por acciones de Vicente: crear una
cuenta de pago y configurar credenciales que yo nunca debo ver ni tocar.

### Plan (investigado, sin ejecutar — depende de que Vicente haga su parte)

**Paso 1 — Inscripción en el Apple Developer Program** (acción de
Vicente, ver PROJECT_STATUS.md / mensaje de esta sesión):

- USD 99/año, requiere Apple ID con 2FA activado, verificación de
  identidad (DNI/pasaporte) y pago.
- Aprobación de cuentas individuales: típicamente 1-3 días hábiles.
- Una vez aprobada, el "Team ID" (10 caracteres alfanuméricos) queda
  visible en developer.apple.com/account → Membership details.

**Paso 2 — API key de App Store Connect para firma automática** (acción
de Vicente, después de que el Paso 1 esté aprobado):

Codemagic soporta firma 100% automática (certificados y provisioning
profiles gestionados solos) usando una API key de App Store Connect, en
vez de tener que exportar/subir certificados `.p12` a mano:

1. App Store Connect → Users and Access → Integrations → App Store
   Connect API → generar una key nueva, acceso "App Manager".
2. Descargar el archivo `.p8` — **solo se puede descargar una vez**.
3. Anotar el Issuer ID (arriba de la tabla) y el Key ID de la key nueva.
4. En Codemagic: Team settings → Team integrations → Developer Portal →
   Manage keys → Add key. Pegar Issuer ID + Key ID, subir el `.p8`.

Ninguno de estos tres valores (Issuer ID, Key ID, archivo `.p8`) debe
pegarse en el chat conmigo ni commitearse en ningún lado — van directo de
Apple/App Store Connect a la UI de Codemagic.

**Paso 3 — lo que hago yo una vez que Vicente complete los pasos 1 y 2**:

- Actualizar `RunCoach-iOS/project.yml`: `DEVELOPMENT_TEAM` con el Team ID
  real (Vicente me lo puede pasar — el Team ID no es secreto, es público
  en cualquier build firmado), `CODE_SIGN_STYLE: Automatic`, y decidir si
  `PRODUCT_BUNDLE_IDENTIFIER` sigue siendo `com.vicente.runcoach` o hay
  que registrar ese App ID explícitamente en el portal (XcodeGen/Codemagic
  con firma automática suelen registrarlo solos si no existe).
- Actualizar `codemagic.yaml`: agregar un workflow o modificar el
  existente para firmar (`integrations: app_store_connect: <nombre de la
  key en Codemagic>`, sección `ios_signing`), sacar
  `CODE_SIGNING_ALLOWED=NO`, y (recién en Fase 13) agregar publishing a
  TestFlight.
- Correr el build de CI y corregir lo que falle — como siempre, sin Mac
  para probar esto antes.

### Estado actual

Nada de esto se hizo todavía. Esperando que Vicente complete el Paso 1.
