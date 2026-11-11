<#
.SYNOPSIS
    Descarga y aplica el fondo de pantalla WallpaperDFC.
    Diseñado para despliegue desde Faronics Deep Freeze Cloud.
#>

# 1. Parámetros de imagen y rutas locales
$ImageUrl = "https://raw.githubusercontent.com/DigitaEM/Digita/main/Wallpaper/Wallpaper_DFC.png"
$DestinationFolder = "C:\Public\Wallpaper"
$ImagePath = Join-Path -Path $DestinationFolder -ChildPath "Wallpaper_DFC.png"

# 2. Crear carpeta local si no existe
if (!(Test-Path -Path $DestinationFolder)) {
    New-Item -ItemType Directory -Force -Path $DestinationFolder | Out-Null
}

# 3. Descargar la imagen
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $ImageUrl -OutFile $ImagePath -UseBasicParsing
    Write-Output "Imagen descargada correctamente en: $ImagePath"
}
catch {
    Write-Error "Error al descargar la imagen: $_"
    exit 1
}

# 4. Definición de API para forzar la actualización del tapiz en Windows
$ActionCode = @"
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@

Add-Type -TypeDefinition $ActionCode -ErrorAction SilentlyContinue

# 5. Aplicar cambios en el Registro de Windows y forzar refresco
$SPI_SETDESKWALLPAPER = 0x0014
$SPIF_UPDATEINIFILE = 0x01
$SPIF_SENDCHANGE = 0x02

Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name wallpaper -Value $ImagePath
[Wallpaper]::SystemParametersInfo($SPI_SETDESKWALLPAPER, 0, $ImagePath, $SPIF_UPDATEINIFILE -bor $SPIF_SENDCHANGE)

Write-Output "Fondo de pantalla WallpaperDFC aplicado exitosamente."