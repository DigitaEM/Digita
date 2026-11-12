<#
.SYNOPSIS
    Fondo de pantalla corporativo para Windows 10 / 11 con ajuste Rellenar (Fill).

.DESCRIPTION
    1. Valida que exista C:\WallpaperFaronics (si no existe, la crea).
    2. Descarga la imagen desde GitHub (URL raw) conservando el nombre Wallpaper_DFC.png.
    3. Crea la tarea programada "Faronics-Wallpaper". Cada vez que un usuario inicia sesion,
       la tarea corre CON ESE USUARIO y aplica el fondo (Rellenar).
         - $TargetUser vacio          -> aplica a TODOS los usuarios.
         - $TargetUser = 'Macsupport' -> aplica solo a ese usuario.

    Si el equipo tiene Deep Freeze con C: en estado Frozen, los cambios se pierden al
    reiniciar. En ese caso, ejecutar con el equipo en estado Thawed.

.PARAMETER TargetUser
    Usuario especifico (por ejemplo: Macsupport). Vacio = todos los usuarios.

.PARAMETER Remove
    Elimina la tarea programada y el script de aplicacion. No borra la imagen.

.NOTES
    Codigos de salida: 0 = correcto | 1 = sin carpeta o sin imagen | 4 = error en la tarea
    Log de este script: C:\WallpaperFaronics\Wallpaper.log
    Log por usuario (al iniciar sesion): %TEMP%\WallpaperFaronics.log
    Archivo guardado sin acentos a proposito, para evitar problemas de codificacion.
#>
[CmdletBinding()]
param(
    [string]$ImageUrl   = 'https://raw.githubusercontent.com/DigitaEM/Digita/main/Wallpaper/Wallpaper_DFC.png',
    [string]$Folder     = 'C:\WallpaperFaronics',
    [string]$FileName   = 'Wallpaper_DFC.png',

    # --- APARTADO DE USUARIO -------------------------------------------------
    # Dejar vacio ('') para aplicar a TODOS los usuarios.
    # Para un usuario especifico, escribir su nombre, por ejemplo: 'Macsupport'
    [string]$TargetUser = '',
    # -------------------------------------------------------------------------

    [switch]$Remove
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

$ImagePath   = Join-Path $Folder $FileName
$TempPath    = "$ImagePath.download"
$LogFile     = Join-Path $Folder 'Wallpaper.log'
$ApplyScript = Join-Path $Folder 'Apply-Wallpaper.ps1'
$TaskName    = 'Faronics-Wallpaper'

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
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $ApplyScript) { Remove-Item -LiteralPath $ApplyScript -Force }
        Write-Log 'Tarea programada y script de aplicacion eliminados.'
        exit 0
    } catch {
        Write-Log "Error al revertir: $($_.Exception.Message)" 'ERROR'
        exit 4
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

    # Permisos: SYSTEM y Administradores control total; Usuarios solo lectura y ejecucion.
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

# --------------------- 3) Script de aplicacion (corre con el usuario al iniciar sesion)
$applyContent = @'
$ErrorActionPreference = 'Stop'
$Image = '@@IMAGE@@'
$Log   = Join-Path $env:TEMP 'WallpaperFaronics.log'
function Log([string]$m) {
    try { Add-Content -LiteralPath $Log -Value ('{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m) } catch { }
}
try {
    if (-not (Test-Path -LiteralPath $Image)) { Log "No existe la imagen: $Image"; exit 1 }

    # Rellenar (Fill) = WallpaperStyle 10 y TileWallpaper 0
    $k = 'HKCU:\Control Panel\Desktop'
    Set-ItemProperty -Path $k -Name 'WallpaperStyle' -Value '10' -Type String
    Set-ItemProperty -Path $k -Name 'TileWallpaper'  -Value '0'  -Type String

    Add-Type -Namespace Faronics -Name WpApi -MemberDefinition '[DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)] public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, string pvParam, uint fWinIni);'

    # SPI_SETDESKWALLPAPER = 0x14 ; SPIF_UPDATEINIFILE -bor SPIF_SENDCHANGE = 3
    $ok = [Faronics.WpApi]::SystemParametersInfo(0x14, 0, $Image, 3)
    if ($ok) { Log "Fondo aplicado (Rellenar): $Image" }
    else     { Log ("SystemParametersInfo fallo. Error Win32: {0}" -f [Runtime.InteropServices.Marshal]::GetLastWin32Error()) }
} catch {
    Log "Error: $($_.Exception.Message)"
    exit 1
}
'@

# ------------------------------------------------ 4) Tarea programada al iniciar sesion
try {
    Set-Content -LiteralPath $ApplyScript -Value $applyContent.Replace('@@IMAGE@@', $ImagePath) -Encoding ASCII
    Write-Log "Script de aplicacion creado: $ApplyScript"

    $action = New-ScheduledTaskAction -Execute 'powershell.exe' `
        -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ApplyScript`""

    if ($TargetUser) {
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $TargetUser
        Write-Log "Alcance: solo el usuario '$TargetUser'."
    } else {
        $trigger = New-ScheduledTaskTrigger -AtLogOn
        Write-Log 'Alcance: todos los usuarios.'
    }

    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

    # Grupo Usuarios (SID S-1-5-32-545): la tarea corre con la cuenta que inicia sesion.
    $registered = $false
    foreach ($group in @('S-1-5-32-545', 'BUILTIN\Users')) {
        try {
            $principal = New-ScheduledTaskPrincipal -GroupId $group -RunLevel Limited
            Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
                -Principal $principal -Settings $settings -Force | Out-Null
            $registered = $true
            Write-Log "Tarea programada '$TaskName' registrada (grupo: $group)."
            break
        } catch {
            Write-Log "No se pudo registrar con el grupo '$group': $($_.Exception.Message)" 'WARN'
        }
    }
    if (-not $registered) { throw 'No fue posible registrar la tarea programada.' }

    Write-Log 'Listo. El fondo se aplicara en el proximo inicio de sesion de cada usuario.'
    exit 0
} catch {
    Write-Log "Error al crear la tarea programada: $($_.Exception.Message)" 'ERROR'
    exit 4
}
