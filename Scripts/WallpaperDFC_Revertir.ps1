<#
.SYNOPSIS
    Revierte WallpaperDFC: elimina la tarea del fondo corporativo y restaura el fondo
    predeterminado de Windows 10 / 11 (ajuste Rellenar).

.DESCRIPTION
    MODO 'Revertir' (por defecto) - Fase 1:
      1. Elimina la tarea 'Faronics-Wallpaper' y Apply-Wallpaper.ps1 (el fondo corporativo
         deja de aplicarse).
      2. Localiza el fondo predeterminado de Windows (tema aero.theme; respaldo: img0.jpg).
      3. Crea la tarea 'Faronics-Wallpaper-Restore': en el siguiente inicio de sesion de cada
         usuario restaura el fondo predeterminado UNA SOLA VEZ. Despues, el usuario puede
         personalizarlo libremente.

    MODO 'Limpiar' - Fase 2 (ejecutar cuando los usuarios ya hayan iniciado sesion):
      Elimina la tarea de restauracion y la carpeta C:\WallpaperFaronics completa
      (incluida la imagen corporativa).

    Si el equipo tiene Deep Freeze con C: en estado Frozen, los cambios se pierden al
    reiniciar. En ese caso, ejecutar con el equipo en estado Thawed.

.NOTES
    Codigos de salida: 0 = correcto | 4 = error
    Log: C:\Windows\Temp\WallpaperFaronics-Revert.log (fuera de la carpeta, para que
    sobreviva a la limpieza). Log por usuario: %TEMP%\WallpaperFaronics.log
    Archivo guardado sin acentos a proposito, para evitar problemas de codificacion.
#>
[CmdletBinding()]
param(
    # --- APARTADOS EDITABLES -------------------------------------------------
    # MODO: 'Revertir' (fase 1) o 'Limpiar' (fase 2)
    [ValidateSet('Revertir', 'Limpiar')]
    [string]$Modo       = 'Revertir',

    # Usar el MISMO valor que en el script de instalacion.
    # Vacio ('') = todos los usuarios. Ejemplo: 'Macsupport'
    [string]$TargetUser = '',
    # -------------------------------------------------------------------------

    [string]$Folder     = 'C:\WallpaperFaronics'
)

$ErrorActionPreference = 'Stop'

$ApplyTask     = 'Faronics-Wallpaper'
$RestoreTask   = 'Faronics-Wallpaper-Restore'
$ApplyScript   = Join-Path $Folder 'Apply-Wallpaper.ps1'
$RestoreScript = Join-Path $Folder 'Restore-Wallpaper.ps1'
$LogFile       = Join-Path $env:WINDIR 'Temp\WallpaperFaronics-Revert.log'

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Output $line
    try { Add-Content -LiteralPath $LogFile -Value $line } catch { }
}

# ------------------------------------------------------------ MODO LIMPIAR (fase 2)
if ($Modo -eq 'Limpiar') {
    try {
        Unregister-ScheduledTask -TaskName $RestoreTask -Confirm:$false -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $ApplyTask   -Confirm:$false -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $Folder) { Remove-Item -LiteralPath $Folder -Recurse -Force }
        Write-Log "Limpieza completada: tareas y carpeta '$Folder' eliminadas."
        exit 0
    } catch {
        Write-Log "Error durante la limpieza: $($_.Exception.Message)" 'ERROR'
        exit 4
    }
}

# --------------------------------------------------------- MODO REVERTIR (fase 1)
# 1) Quitar el fondo corporativo
try {
    Unregister-ScheduledTask -TaskName $ApplyTask -Confirm:$false -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $ApplyScript) { Remove-Item -LiteralPath $ApplyScript -Force }
    Write-Log "Tarea '$ApplyTask' y script de aplicacion eliminados."
} catch {
    Write-Log "Error al eliminar la tarea del fondo corporativo: $($_.Exception.Message)" 'ERROR'
    exit 4
}

# 2) Localizar el fondo predeterminado de Windows
function Get-DefaultWallpaper {
    $candidates = @()
    $theme = Join-Path $env:WINDIR 'Resources\Themes\aero.theme'
    if (Test-Path -LiteralPath $theme) {
        $m = Select-String -LiteralPath $theme -Pattern '^\s*Wallpaper\s*=\s*(.+?)\s*$' | Select-Object -First 1
        if ($m) { $candidates += [Environment]::ExpandEnvironmentVariables($m.Matches[0].Groups[1].Value) }
    }
    $candidates += (Join-Path $env:WINDIR 'Web\Wallpaper\Windows\img0.jpg')
    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath $c)) { return $c }
    }
    return ''
}

$defaultImage = Get-DefaultWallpaper
if ($defaultImage) {
    Write-Log "Fondo predeterminado de Windows localizado: $defaultImage"
} else {
    Write-Log 'No se encontro el fondo predeterminado; se dejara el escritorio sin imagen (color solido).' 'WARN'
}

# 3) Tarea que restaura el fondo, una sola vez por usuario, en su proximo inicio de sesion
$token = Get-Date -Format 'yyyyMMddHHmmss'

$restoreContent = @'
$ErrorActionPreference = 'Stop'
$Image = '@@IMAGE@@'
$Token = '@@TOKEN@@'
$Log   = Join-Path $env:TEMP 'WallpaperFaronics.log'
function Log([string]$m) {
    try { Add-Content -LiteralPath $Log -Value ('{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m) } catch { }
}
try {
    # Si este usuario ya fue restaurado en esta reversa, no hacer nada (respeta su personalizacion)
    $reg = 'HKCU:\Software\Faronics'
    $cur = $null
    if (Test-Path -LiteralPath $reg) { $cur = (Get-ItemProperty -LiteralPath $reg).WallpaperRestoreToken }
    if ($cur -eq $Token) { exit 0 }

    # Rellenar (Fill) = WallpaperStyle 10 y TileWallpaper 0 (valores predeterminados de Windows)
    $k = 'HKCU:\Control Panel\Desktop'
    Set-ItemProperty -Path $k -Name 'WallpaperStyle' -Value '10' -Type String
    Set-ItemProperty -Path $k -Name 'TileWallpaper'  -Value '0'  -Type String

    Add-Type -Namespace Faronics -Name WpApi -MemberDefinition '[DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)] public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, string pvParam, uint fWinIni);'

    # SPI_SETDESKWALLPAPER = 0x14 ; SPIF_UPDATEINIFILE -bor SPIF_SENDCHANGE = 3
    $ok = [Faronics.WpApi]::SystemParametersInfo(0x14, 0, $Image, 3)
    if ($ok) {
        if (-not (Test-Path -LiteralPath $reg)) { New-Item -Path $reg -Force | Out-Null }
        Set-ItemProperty -Path $reg -Name 'WallpaperRestoreToken' -Value $Token -Type String
        Log "Fondo predeterminado restaurado: [$Image]"
    } else {
        Log ("SystemParametersInfo fallo. Error Win32: {0}" -f [Runtime.InteropServices.Marshal]::GetLastWin32Error())
    }
} catch {
    Log "Error: $($_.Exception.Message)"
    exit 1
}
'@

try {
    if (-not (Test-Path -LiteralPath $Folder -PathType Container)) {
        New-Item -ItemType Directory -Path $Folder -Force | Out-Null
        & icacls.exe $Folder /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-32-545:(OI)(CI)RX' | Out-Null
        Write-Log "Carpeta creada para el script de restauracion: $Folder"
    }

    $content = $restoreContent.Replace('@@IMAGE@@', $defaultImage).Replace('@@TOKEN@@', $token)
    Set-Content -LiteralPath $RestoreScript -Value $content -Encoding ASCII
    Write-Log "Script de restauracion creado: $RestoreScript"

    $action = New-ScheduledTaskAction -Execute 'powershell.exe' `
        -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$RestoreScript`""

    if ($TargetUser) {
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $TargetUser
        Write-Log "Alcance de la restauracion: solo el usuario '$TargetUser'."
    } else {
        $trigger = New-ScheduledTaskTrigger -AtLogOn
        Write-Log 'Alcance de la restauracion: todos los usuarios.'
    }

    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

    $registered = $false
    foreach ($group in @('S-1-5-32-545', 'BUILTIN\Users')) {
        try {
            $principal = New-ScheduledTaskPrincipal -GroupId $group -RunLevel Limited
            Register-ScheduledTask -TaskName $RestoreTask -Action $action -Trigger $trigger `
                -Principal $principal -Settings $settings -Force | Out-Null
            $registered = $true
            Write-Log "Tarea '$RestoreTask' registrada (grupo: $group)."
            break
        } catch {
            Write-Log "No se pudo registrar con el grupo '$group': $($_.Exception.Message)" 'WARN'
        }
    }
    if (-not $registered) { throw 'No fue posible registrar la tarea de restauracion.' }

    Write-Log 'Fase 1 completa. El fondo de Windows se restaurara en el proximo inicio de sesion de cada usuario.'
    Write-Log "Cuando todos hayan iniciado sesion, ejecute este script con `$Modo = 'Limpiar' para eliminar la carpeta y la tarea."
    exit 0
} catch {
    Write-Log "Error al crear la tarea de restauracion: $($_.Exception.Message)" 'ERROR'
    exit 4
}