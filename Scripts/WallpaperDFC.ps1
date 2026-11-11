<#
.SYNOPSIS
    Establece un fondo de pantalla corporativo para TODOS los usuarios de un equipo
    con Windows 10 / 11, usando Rellenar (Fill) como ajuste.

.DESCRIPTION
    1. Valida que exista C:\WallpaperFaronics (si no existe, la crea).
    2. Descarga la imagen desde GitHub (URL raw) conservando el nombre Wallpaper_DFC.png.
    3. Configura el fondo mediante la directiva de equipo (HKLM), de modo que aplica a
       cualquier usuario que inicie sesion (existente o futuro) con ajuste Rellenar.

    IMPORTANTE (Deep Freeze): si C: esta Frozen, los cambios se pierden al reiniciar.
    Ejecutar con el equipo en estado Thawed (por ejemplo, mediante una tarea de
    estacion de trabajo "Batch File" de Deep Freeze, que descongela y vuelve a congelar).

.PARAMETER Remove
    Revierte la configuracion: elimina la directiva de fondo (no borra la imagen).

.NOTES
    Codigos de salida: 0 = correcto | 1 = sin imagen disponible | 3 = error de registro
    Archivo guardado intencionalmente sin acentos para evitar problemas de codificacion
    en Windows PowerShell 5.1.
#>
[CmdletBinding()]
param(
    [string]$ImageUrl       = 'https://raw.githubusercontent.com/DigitaEM/Digita/main/Wallpaper/Wallpaper_DFC.png',
    [string]$Folder         = 'C:\WallpaperFaronics',
    [string]$FileName       = 'Wallpaper_DFC.png',
    [string]$ExpectedSha256 = '',     # Opcional: hash SHA256 esperado de la imagen
    [switch]$Remove
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

$ImagePath = Join-Path $Folder $FileName
$TempPath  = "$ImagePath.download"
$LogFile   = Join-Path $Folder 'Wallpaper.log'
$PolicyKey = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Output $line
    try {
        if (Test-Path -LiteralPath $Folder -PathType Container) {
            Add-Content -LiteralPath $LogFile -Value $line
        }
    } catch { }
}

# Abre la clave de directivas en la vista de 64 bits (aunque PowerShell corra en 32 bits)
function Open-PolicyKey {
    $view = [Microsoft.Win32.RegistryView]::Default
    if ([Environment]::Is64BitOperatingSystem) { $view = [Microsoft.Win32.RegistryView]::Registry64 }
    $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, $view)
    return $base.CreateSubKey($PolicyKey)
}

# Verifica la firma PNG (evita guardar una pagina HTML de error como si fuera la imagen)
function Test-Png {
    param([string]$Path)
    $fs = [System.IO.File]::OpenRead($Path)
    try {
        $b = New-Object byte[] 8
        $n = $fs.Read($b, 0, 8)
    } finally { $fs.Close() }
    return ($n -eq 8 -and $b[0] -eq 0x89 -and $b[1] -eq 0x50 -and $b[2] -eq 0x4E -and $b[3] -eq 0x47 `
            -and $b[4] -eq 0x0D -and $b[5] -eq 0x0A -and $b[6] -eq 0x1A -and $b[7] -eq 0x0A)
}

# ---------------------------------------------------------------- Modo reversa
if ($Remove) {
    try {
        $key = Open-PolicyKey
        try {
            $key.DeleteValue('Wallpaper', $false)
            $key.DeleteValue('WallpaperStyle', $false)
        } finally { $key.Close() }
        Write-Log 'Directiva de fondo de pantalla eliminada. Aplica en el proximo inicio de sesion.'
        exit 0
    } catch {
        Write-Log "No se pudo eliminar la directiva: $($_.Exception.Message)" 'ERROR'
        exit 3
    }
}

# ------------------------------------------------- 1) Carpeta C:\WallpaperFaronics
try {
    if (-not (Test-Path -LiteralPath $Folder -PathType Container)) {
        New-Item -ItemType Directory -Path $Folder -Force | Out-Null
        Write-Log "Carpeta creada: $Folder"
    } else {
        Write-Log "La carpeta ya existe: $Folder"
    }

    # Permisos: SYSTEM y Administradores control total; Usuarios solo lectura.
    # Se usan SID conocidos para que funcione en Windows en cualquier idioma.
    & icacls.exe $Folder /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-32-545:(OI)(CI)RX' | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Log "icacls devolvio el codigo $LASTEXITCODE (se continua)." 'WARN' }
} catch {
    Write-Log "Error al preparar la carpeta: $($_.Exception.Message)" 'ERROR'
    exit 1
}

# ------------------------------------------------------------- 2) Descarga
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$downloaded = $false
for ($i = 1; $i -le 3 -and -not $downloaded; $i++) {
    try {
        if (Test-Path -LiteralPath $TempPath) { Remove-Item -LiteralPath $TempPath -Force }
        Invoke-WebRequest -Uri $ImageUrl -OutFile $TempPath -UseBasicParsing -TimeoutSec 60

        if (-not (Test-Png $TempPath)) {
            throw 'El archivo descargado no es un PNG valido (verifique que la URL sea la version raw).'
        }
        if ($ExpectedSha256 -and ((Get-FileHash -LiteralPath $TempPath -Algorithm SHA256).Hash -ne $ExpectedSha256)) {
            throw 'El hash SHA256 de la imagen no coincide con el esperado.'
        }
        Move-Item -LiteralPath $TempPath -Destination $ImagePath -Force
        $downloaded = $true
        Write-Log "Imagen descargada: $ImagePath"
    } catch {
        Write-Log "Intento $i de 3 fallido: $($_.Exception.Message)" 'WARN'
        if ($i -lt 3) { Start-Sleep -Seconds (5 * $i) }
    }
}
if (Test-Path -LiteralPath $TempPath) { Remove-Item -LiteralPath $TempPath -Force -ErrorAction SilentlyContinue }

if (-not $downloaded) {
    if ((Test-Path -LiteralPath $ImagePath) -and (Test-Png $ImagePath)) {
        Write-Log 'No se pudo descargar; se usara la imagen que ya existia en el equipo.' 'WARN'
    } else {
        Write-Log 'No se pudo descargar la imagen y no hay copia local. Proceso cancelado.' 'ERROR'
        exit 1
    }
}

# ------------------------------------- 3) Fondo para todos los usuarios (Rellenar)
# WallpaperStyle: 0 Centrar | 2 Estirar | 6 Ajustar | 10 Rellenar | 22 Span
try {
    $key = Open-PolicyKey
    try {
        $key.SetValue('Wallpaper',      $ImagePath, [Microsoft.Win32.RegistryValueKind]::String)
        $key.SetValue('WallpaperStyle', '10',       [Microsoft.Win32.RegistryValueKind]::String)
    } finally { $key.Close() }
    Write-Log "Directiva aplicada: Wallpaper=$ImagePath, WallpaperStyle=10 (Rellenar)."
    Write-Log 'El fondo se vera en el proximo inicio de sesion de cada usuario.'
    exit 0
} catch {
    Write-Log "No se pudo escribir la directiva en el registro: $($_.Exception.Message)" 'ERROR'
    exit 3
}
