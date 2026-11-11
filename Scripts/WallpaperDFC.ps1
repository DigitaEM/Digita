<#
.SYNOPSIS
    Descarga y aplica el fondo de pantalla WallpaperDFC a todos los usuarios.
    Diseñado para ejecución masiva como SYSTEM desde Faronics DFC.
#>

# 1. URL directa del archivo (Raw)
$ImageUrl = "https://raw.githubusercontent.com/DigitaEM/Digita/main/Wallpaper/Wallpaper_DFC.png"
$DestinationFolder = "C:\Public\Wallpaper"
$ImagePath = Join-Path -Path $DestinationFolder -ChildPath "Wallpaper_DFC.png"

# 2. Crear directorio de destino
if (!(Test-Path -Path $DestinationFolder)) {
    New-Item -ItemType Directory -Force -Path $DestinationFolder | Out-Null
}

# 3. Forzar TLS 1.2 y descargar la imagen limpia
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $WebClient = New-Object System.Net.WebClient
    $WebClient.DownloadFile($ImageUrl, $ImagePath)
    Write-Output "Imagen descargada con exito en: $ImagePath"
}
catch {
    Write-Error "Error al descargar la imagen: $_"
    exit 1
}

# 4. Modificar el registro para el usuario activo y futuros usuarios (Default Profile)
$ActionCode = @"
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@

Add-Type -TypeDefinition $ActionCode -ErrorAction SilentlyContinue

# Aplicar en todas las siones de usuario cargadas en HKU
Get-ChildItem -Path Registry::HKEY_USERS | Where-Name -NotMatch "S-1-5-18|S-1-5-19|S-1-5-20|_Classes" | ForEach-Object {
    $UserDesktopPath = "Registry::$($_.Name)\Control Panel\Desktop"
    if (Test-Path $UserDesktopPath) {
        Set-ItemProperty -Path $UserDesktopPath -Name wallpaper -Value $ImagePath -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $UserDesktopPath -Name WallpaperStyle -Value "2" -ErrorAction SilentlyContinue # 2 = Stretched / Estirado
        Set-ItemProperty -Path $UserDesktopPath -Name TileWallpaper -Value "0" -ErrorAction SilentlyContinue
    }
}

# Refrescar escritorio
$SPI_SETDESKWALLPAPER = 0x0014
$SPIF_UPDATEINIFILE = 0x01
$SPIF_SENDCHANGE = 0x02
[Wallpaper]::SystemParametersInfo($SPI_SETDESKWALLPAPER, 0, $ImagePath, $SPIF_UPDATEINIFILE -bor $SPIF_SENDCHANGE)

Write-Output "Proceso de WallpaperDFC finalizado correctamente."
