# Ocultar errores no críticos
$ErrorActionPreference = 'SilentlyContinue'

# Obtener Edición de Windows
$Caption = (Get-CimInstance Win32_OperatingSystem).Caption

# Obtener Versión (ej. 22H2, 23H2) desde el Registro
$DisplayVersion = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "DisplayVersion").DisplayVersion

# Obtener Build / Versión SO
$Build = (Get-CimInstance Win32_OperatingSystem).Version
$UBR = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "UBR").UBR
if ($UBR) { $FullBuild = "$Build.$UBR" } else { $FullBuild = $Build }

# Obtener Estado de Licencia
$LicenseStatus = (Get-CimInstance SoftwareLicensingProduct -Filter "PartialProductKey IS NOT NULL AND Name LIKE 'Windows%'").LicenseStatus
if ($LicenseStatus -eq 1) { $EstadoLicencia = "Activo" } else { $EstadoLicencia = "Sin licencia" }

# Mostrar en listado vertical limpio
Write-Host "Edicion: $Caption"
Write-Host "Version: $DisplayVersion"
Write-Host "Version SO: $FullBuild"
Write-Host "Estado de Licencia: $EstadoLicencia"