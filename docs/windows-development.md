# Desarrollo desde Windows

## Entorno verificado (Fase 0)

| Componente | Estado |
|---|---|
| Windows | 11 Home, build 10.0.26200, x64 |
| CPU | AMD Ryzen AI 7 350 (8 núcleos / 16 hilos) |
| RAM | ~14 GB |
| Disco libre | ~334 GB en C:\ |
| Git | 2.54.0.windows.1 — ya configurado (`user.name`/`user.email`) |
| Swift toolchain (swift.org, Windows) | 6.3.3, instalado vía winget (`Swift.Toolchain`). `swift build`/`swift test` funcionan — ver sección siguiente para el setup necesario |
| Visual Studio 2022 Build Tools + Windows 11 SDK (10.0.22621.0) | instalado vía winget (`Microsoft.VisualStudio.2022.BuildTools`, componentes `VC.Tools.x86.x64` + `Windows11SDK.22621`) — requerido por Swift para enlazar en Windows |
| Python | 3.13.13 (no es parte del stack del proyecto, ya estaba presente) |
| Node/npm | v24.15.0 / 11.12.1 (no es parte del stack del proyecto, ya estaba presente) |
| VS Code | 1.118.0 |
| winget | 1.29.280 |
| Xcode / macOS | No disponible — no aplica en Windows, se usa CI remoto (ver [docs/ios-build.md](ios-build.md)) |
| GitHub CLI (`gh`) | No instalado todavía — se instalará cuando conectemos GitHub (Fase 4) |
| Docker | No instalado — no es necesario para este proyecto por ahora |

## Qué se puede hacer 100% en Windows

- Todo **RunCoachCore**: escribir modelos, lógica de métricas, Coach
  Decision Engine, Simulation Engine, y correr sus tests con `swift test`.
- Editar documentación, gestionar Git, preparar CI (`codemagic.yaml`,
  `project.yml`) aunque no se puedan ejecutar builds de Xcode localmente.
- Todo lo relacionado con investigación, arquitectura, scripting de
  automatización.

## Qué NO se puede hacer en Windows

- Compilar o correr `RunCoach-iOS` (SwiftUI/CoreBluetooth/CoreLocation/
  AVFoundation) — esos frameworks no existen fuera de Apple platforms. Se
  valida en Codemagic (macOS cloud).
- Probar BLE/GPS/audio reales de iOS — requiere iPhone físico (Fases 14+).
- Usar Xcode Interface Builder / Previews de SwiftUI — no hay Xcode en
  Windows.

## Comandos de referencia para RunCoachCore

**Importante — hay que preparar el entorno en cada terminal PowerShell
nueva.** El toolchain de Swift para Windows necesita las variables de
entorno de Visual Studio (MSVC `link.exe`, `INCLUDE`, `LIB`) y `SDKROOT`
apuntando al SDK de Windows que trae el propio toolchain. Estas variables no
son persistentes entre sesiones — sin ellas, `swift build` falla con
`unable to load standard library for target 'x86_64-unknown-windows-msvc'`
o `could not find CLI tool 'link'`. Por eso existe
[`scripts/setup-swift-env.ps1`](../scripts/setup-swift-env.ps1):

```powershell
# Desde la raíz del repo, en PowerShell (nota el "." inicial — dot-sourcing):
. .\scripts\setup-swift-env.ps1
cd RunCoachCore
swift build
swift test
```

En una terminal Bash/Git Bash equivalente (sin las variables de VS, solo
funciona si el proceso las heredó de una PowerShell que ya corrió el script
arriba, o agregando manualmente `SDKROOT` y el PATH del toolchain):

```bash
export PATH="/c/Users/vicen/AppData/Local/Programs/Swift/Toolchains/6.3.3+Asserts/usr/bin:/c/Users/vicen/AppData/Local/Programs/Swift/Runtimes/6.3.3/usr/bin:$PATH"
export SDKROOT="C:\\Users\\vicen\\AppData\\Local\\Programs\\Swift\\Platforms\\6.3.3\\Windows.platform\\Developer\\SDKs\\Windows.sdk"
# además se necesitan INCLUDE/LIB/PATH de MSVC — más simple usar el script de PowerShell
```

Estos dos comandos (`swift build`, `swift test`) son el criterio de
aceptación mínimo para cualquier cambio en RunCoachCore: si no compilan o
los tests fallan, el cambio no está terminado.

### Advertencia benigna conocida

`swift build`/`swift test` imprimen una advertencia sobre no poder crear un
symlink en `.build\debug` (`encountered an I/O error (code: 512)`). No
afecta el resultado del build ni de los tests — es una limitación de
symlinks en esta carpeta (dentro de OneDrive). Se puede ignorar.

### `git push` puede fallar transitoriamente por OneDrive

Como el repo vive dentro de una carpeta sincronizada por OneDrive, a veces
`git push` falla con algo como:

```
error: unable to open loose object <hash>: Permission denied
fatal: object <hash> cannot be read
```

Es OneDrive reteniendo un lock momentáneo sobre un archivo interno de
`.git/objects` mientras lo sincroniza — no es corrupción del repo. Alcanza
con reintentar `git push` (funcionó a la primera en la única vez que pasó,
en Fase 10). Si se repite seguido, correr `git fsck --full` para confirmar
que no hay daño real (los `dangling blob`/`dangling commit` que puede
listar son normales, no son un problema).

## Editor

VS Code ya está instalado. Para autocompletado/soporte de Swift se puede
instalar la extensión oficial `swiftlang.swift-vscode` más adelante si hace
falta (no crítico para el flujo actual, que pasa mayormente por Claude
Code).
