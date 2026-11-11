<#
.SYNOPSIS
    Crea C:\WallpaperFaronics, descarga Wallpaper_DFC.png y la configura como fondo de pantalla (Rellenar).
#>

# 1. Definir rutas y crear carpeta local C:\WallpaperFaronics
$TargetDir = "C:\WallpaperFaronics"
$ImagePath = Join-Path -Path $TargetDir -ChildPath "Wallpaper_DFC.png"
$ImageUrl  = "https://raw.githubusercontent.com/DigitaEM/Digita/main/Wallpaper/Wallpaper_DFC.png"

if (!(Test-Path -Path $TargetDir)) {
    New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null
}

# 2. Descargar la imagen desde GitHub (Raw)
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $WebClient = New-Object System.Net.WebClient
    $WebClient.DownloadFile($ImageUrl, $ImagePath)
    Write-Output "Imagen descargada correctamente en: $ImagePath"
}
catch {
    Write-Error "Error al descargar la imagen desde GitHub: $_"
    exit 1
}

# 3. Aplicar en la política por defecto del Registro (Todos los usuarios)
# WallpaperStyle = 10 (Rellenar / Fill), TileWallpaper = 0
$RegPaths = @(
    "HKCU:\Control Panel\Desktop",
    "Registry::HKEY_USERS\.DEFAULT\Control Panel\Desktop"
)

foreach ($path in $RegPaths) {
    if (Test-Path $path) {
        Set-ItemProperty -Path $path -Name wallpaper -Value $ImagePath -Force
        Set-ItemProperty -Path $path -Name WallpaperStyle -Value "10" -Force
        Set-ItemProperty -Path $path -Name TileWallpaper -Value "0" -Force
    }
}

# 4. Actualizar en todos los perfiles de usuario activos actualmente en HKEY_USERS
Get-ChildItem -Path Registry::HKEY_USERS | Where-Name -NotMatch "S-1-5-18|S-1-5-19|S-1-5-20|_Classes" | ForEach-Object {
    $UserDesktop = "Registry::$($_.Name)\Control Panel\Desktop"
    if (Test-Path $UserDesktop) {
        Set-ItemProperty -Path $UserDesktop -Name wallpaper -Value $ImagePath -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $UserDesktop -Name WallpaperStyle -Value "10" -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $UserDesktop -Name TileWallpaper -Value "0" -Force -ErrorAction SilentlyContinue
    }
}

# 5. Intentar refrescar la interfaz activa mediante DLL Native (User32)
$Signature = @"
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@
Add-Type -TypeDefinition $Signature -ErrorAction SilentlyContinue
[Wallpaper]::SystemParametersInfo(0x0014, 0, $ImagePath, 0x01 -bor 0x02) | Out-Null

Write-Output "Proceso completado. Fondo configurado en modo Rellenar."
