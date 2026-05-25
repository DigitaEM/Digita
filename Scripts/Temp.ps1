<#
.SYNOPSIS
    Limpia archivos temporales de sistema y de todos los perfiles de usuario.
.DESCRIPTION
    Este script recorre cada carpeta de usuario en C:\Users y elimina el contenido de AppData\Local\Temp.
    También limpia la carpeta Temp de Windows y la caché de Prefetch.
#>

# 1. Verificar si se ejecuta como Administrador
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Por favor, ejecuta este script como Administrador para poder limpiar todos los perfiles."
    break
}

Write-Host "--- Iniciando limpieza profunda de temporales ---" -ForegroundColor Cyan

# 2. Definir rutas de sistema (Globales)
$SystemTempPaths = @(
    "C:\Windows\Temp\*",
    "C:\Windows\Prefetch\*"
)

# 3. Obtener todas las carpetas de perfiles de usuario (omitiendo carpetas de sistema como Public o All Users)
$UserProfiles = Get-ChildItem -Path "C:\Users" -Directory | Where-Object { $_.Name -notmatch "Public|Default|All Users" }

foreach ($Profile in $UserProfiles) {
    $UserTempPath = "C:\Users\$($Profile.Name)\AppData\Local\Temp\*"
    
    if (Test-Path $UserTempPath) {
        Write-Host "Limpiando temporales del usuario: $($Profile.Name)..." -ForegroundColor Yellow
        Remove-Item -Path $UserTempPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# 4. Limpiar carpetas de sistema
Write-Host "Limpiando carpetas temporales de Windows..." -ForegroundColor Yellow
foreach ($Path in $SystemTempPaths) {
    if (Test-Path $Path) {
        Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# 5. Vaciar Papelera de Reciclaje
Write-Host "Vaciando Papelera de Reciclaje..." -ForegroundColor Yellow
Clear-RecycleBin -Confirm:$false -ErrorAction SilentlyContinue

Write-Host "--- Limpieza completada con éxito ---" -ForegroundColor Green