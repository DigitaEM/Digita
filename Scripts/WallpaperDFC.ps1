# 1. Validar y crear la carpeta en C:\WallpaperFaronics
$folderPath = "C:\WallpaperFaronics"
if (-not (Test-Path -Path $folderPath)) {
    New-Item -Path $folderPath -ItemType Directory -Force | Out-Null
}

# 2. Ruta del archivo y URL Raw de GitHub
$imagePath = Join-Path -Path $folderPath -ChildPath "Wallpaper_DFC.png"
$imageUrl = "https://raw.githubusercontent.com/DigitaEM/Digita/main/Wallpaper/Wallpaper_DFC.png"

# Forzar uso de TLS 1.2 para asegurar la descarga segura desde GitHub
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Descargar la imagen
Invoke-WebRequest -Uri $imageUrl -OutFile $imagePath -UseBasicParsing

# 3. Configurar el estilo de pantalla en "Rellenar" (Fill = WallpaperStyle "10", TileWallpaper "0")
$regPathHKCU = "HKCU:\Control Panel\Desktop"
Set-ItemProperty -Path $regPathHKCU -Name WallpaperStyle -Value "10"
Set-ItemProperty -Path $regPathHKCU -Name TileWallpaper -Value "0"
Set-ItemProperty -Path $regPathHKCU -Name Wallpaper -Value $imagePath

# Aplicar a perfiles nuevos (Default User Hive)
$defaultHive = "HKU\DefaultUser"
$defaultRegPath = "C:\Users\Default\NTUSER.DAT"
if (Test-Path $defaultRegPath) {
    reg load $defaultHive $defaultRegPath | Out-Null
    Set-ItemProperty -Path "Registry::$defaultHive\Control Panel\Desktop" -Name WallpaperStyle -Value "10"
    Set-ItemProperty -Path "Registry::$defaultHive\Control Panel\Desktop" -Name TileWallpaper -Value "0"
    Set-ItemProperty -Path "Registry::$defaultHive\Control Panel\Desktop" -Name Wallpaper -Value $imagePath
    [gc]::collect()
    reg unload $defaultHive | Out-Null
}

# Refrescar los cambios en la sesión activa inmediatamente mediante API de Windows
$code = @"
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@
Add-Type -TypeDefinition $code
[Wallpaper]::SystemParametersInfo(0x0014, 0, $imagePath, 0x01 -bor 0x02) | Out-Null
