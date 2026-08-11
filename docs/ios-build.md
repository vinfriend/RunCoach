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

Este archivo se actualizará con el `project.yml` real y el `codemagic.yaml`
real cuando lleguemos a la Fase 4 (Proyecto iOS + CI macOS).

## Estado actual

- Cuenta de Codemagic: **no creada todavía** (no requiere pago para el free
  tier, pero sí login/autorización — acción de Vicente cuando lleguemos a
  Fase 4).
- Repo en GitHub: **no creado todavía** (Fase 0/1 solo prepara Git local).
- `project.yml` / `codemagic.yaml`: no creados todavía — se crean en Fase 4.

## Próximos pasos (Fase 4, no ahora)

1. Crear repo en GitHub (requiere que Vicente autorice/loguee la cuenta si
   no hay ya un `gh auth login` activo).
2. Crear `project.yml` (XcodeGen) describiendo el target `RunCoach-iOS`.
3. Crear `codemagic.yaml` con el pipeline: checkout → xcodegen generate →
   build → test → (más adelante) firma y TestFlight.
4. Conectar Codemagic al repo (acción de Vicente: login/autorización OAuth
   con GitHub).
