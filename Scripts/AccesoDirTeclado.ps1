<#
.SYNOPSIS
    Crea un acceso directo al Teclado en pantalla (OSK) en el Escritorio Público.
    Diseñado para despliegue masivo mediante Faronics Deep Freeze Cloud.
#>

# 1. Definir la ruta del Escritorio Público (Aplica a todos los usuarios)
$PublicDesktop = [System.IO.Path]::Combine($env:Public, "Desktop")
$ShortcutPath = Join-Path -Path $PublicDesktop -ChildPath "Teclado en pantalla.lnk"

# 2. Definir la ruta del ejecutable del Teclado en pantalla (OSK)
$TargetPath = "$env:SystemRoot\System32\osk.exe"

try {
    # 3. Crear la instancia del objeto WScript.Shell
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)

    # 4. Configurar las propiedades del acceso directo
    $Shortcut.TargetPath = $TargetPath
    $Shortcut.IconLocation = "$TargetPath, 0"
    $Shortcut.Description = "Iniciar Teclado en pantalla de Windows"
    $Shortcut.WorkingDirectory = "$env:SystemRoot\System32"
    
    # 5. Guardar el archivo .lnk
    $Shortcut.Save()

    Write-Output "Acceso directo creado exitosamente en: $ShortcutPath"
}
catch {
    Write-Error "Error al crear el acceso directo: $_"
}