<#
.SYNOPSIS
    Descarga directamente el binario de la imagen y la establece como fondo de pantalla (Rellenar).
#>

$ErrorActionPreference = "Stop"

# 1. Crear carpeta local C:\WallpaperFaronics
$TargetDir = "C:\WallpaperFaronics"
$ImagePath = Join-Path -Path $TargetDir -ChildPath "Wallpaper_DFC.png"
$ImageUrl  = "https://raw.githubusercontent.com/DigitaEM/Digita/main/Wallpaper/Wallpaper_DFC.png"

if (!(Test-Path -Path $TargetDir)) {
    New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null
}

# 2. Descarga directa limpia del archivo ejecutable binario (forzando TLS 1.2)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$WebClient = New-Object System.Net.WebClient
$WebClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
$WebClient.DownloadFile($ImageUrl, $ImagePath)

# Verificar que se haya creado la imagen y no un archivo HTML
$FileSize = (Get-Item $ImagePath).Length
if ($FileSize -lt 5000) {
    # Si mide menos de 5KB, probablemente descargó un error o texto en vez de la imagen real
    Remove-Item $ImagePath -Force
    throw "La imagen descargada no es valida o esta corrupta."
}

# 3. Aplicar en Registro de Windows (Modo Rellenar: Style 10, Tile 0)
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

# Aplicar a todos los perfiles cargados en HKEY_USERS
Get-ChildItem -Path Registry::HKEY_USERS | Where-Name -NotMatch "S-1-5-18|S-1-5-19|S-1-5-20|_Classes" | ForEach-Object {
    $UserDesktop = "Registry::$($_.Name)\Control Panel\Desktop"
    if (Test-Path $UserDesktop) {
        Set-ItemProperty -Path $UserDesktop -Name wallpaper -Value $ImagePath -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $UserDesktop -Name WallpaperStyle -Value "10" -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $UserDesktop -Name TileWallpaper -Value "0" -ErrorAction SilentlyContinue
    }
}

# 4. Refrescar la interfaz de usuario activa
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

Write-Output "Fondo WallpaperDFC aplicado con exito."
