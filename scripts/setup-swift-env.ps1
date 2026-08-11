<#
.SYNOPSIS
  Configura el entorno de PowerShell actual para poder usar `swift build` /
  `swift test` en Windows.

.DESCRIPTION
  El toolchain de Swift para Windows necesita las variables de entorno de
  Visual Studio (INCLUDE, LIB, PATH del linker MSVC, etc.) y SDKROOT
  apuntando al SDK de Windows que trae el propio toolchain. Estas variables
  NO son persistentes entre sesiones de shell nuevas, así que hay que
  cargarlas en cada terminal nueva antes de compilar.

.USAGE
  Desde la raíz del repo, en una terminal PowerShell nueva:
    . .\scripts\setup-swift-env.ps1
    cd RunCoachCore
    swift build
    swift test

  (El "." inicial es necesario — "dot-sourcing" — para que las variables de
  entorno queden en tu sesión actual en vez de perderse al terminar el
  script.)
#>

$vsDevCmd = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat"
if (-not (Test-Path $vsDevCmd)) {
    throw "No se encontró VsDevCmd.bat en $vsDevCmd. ¿Está instalado Visual Studio Build Tools 2022?"
}

$swiftToolchainBin = "C:\Users\vicen\AppData\Local\Programs\Swift\Toolchains\6.3.3+Asserts\usr\bin\"
$swiftRuntimeBin = "C:\Users\vicen\AppData\Local\Programs\Swift\Runtimes\6.3.3\usr\bin\"
$sdkRoot = "C:\Users\vicen\AppData\Local\Programs\Swift\Platforms\6.3.3\Windows.platform\Developer\SDKs\Windows.sdk"

if (-not (Test-Path $swiftToolchainBin)) {
    throw "No se encontró el toolchain de Swift en $swiftToolchainBin. ¿Está instalado Swift.Toolchain (winget)?"
}

$tmpFile = Join-Path $env:TEMP "vsenv_$([guid]::NewGuid().ToString('N')).txt"
cmd /c "`"$vsDevCmd`" -arch=x64 -host_arch=x64 && set" > $tmpFile 2>&1

Get-Content $tmpFile | Where-Object {
    $_ -match "^(INCLUDE|LIB|LIBPATH|Path|WindowsSdkDir|WindowsSDKVersion|VCToolsInstallDir|UniversalCRTSdkDir|UCRTVersion)="
} | ForEach-Object {
    $parts = $_ -split '=', 2
    Set-Item -Path "Env:$($parts[0])" -Value $parts[1]
}
Remove-Item $tmpFile -ErrorAction SilentlyContinue

$env:Path = "$swiftToolchainBin;$swiftRuntimeBin;" + $env:Path
$env:SDKROOT = $sdkRoot

Write-Output "Entorno Swift listo. swift --version:"
swift --version
