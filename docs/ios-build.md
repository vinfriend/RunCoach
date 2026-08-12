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

- Cuenta de Codemagic: **no creada todavía** — requiere login/autorización
  de Vicente (acción pendiente, ver PROJECT_STATUS.md).
- Repo en GitHub: **no creado todavía** — requiere que Vicente cree el repo
  y/o autorice `gh auth login` (acción pendiente).
- `project.yml` / `codemagic.yaml`: **creados** (Fase 4). Sin validar en CI
  todavía porque no hay repo/Codemagic conectados.
- GitHub CLI (`gh`): instalado vía winget, sin autenticar todavía.
