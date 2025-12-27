# ============================================================
# Script PowerShell para desactivar GameDVR
# Auto-elevación a Administrador
# ============================================================

# 1. Verificación de permisos de administrador
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Solicitando permisos de administrador..." -ForegroundColor Yellow
    
    # Relanza el script actual con elevación (RunAs)
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = "powershell.exe"
    $processInfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $processInfo.Verb = "RunAs"
    [System.Diagnostics.Process]::Start($processInfo)
    Exit
}

# 2. Configuración de variables
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"
$regName = "AppCaptureEnabled"
$regValue = 0

Write-Host "Iniciando configuración del registro..." -ForegroundColor Cyan

try {
    # 3. Verificar si la ruta existe, si no, crearla
    if (-not (Test-Path $regPath)) {
        Write-Host "La ruta no existe. Creando: $regPath" -ForegroundColor Yellow
        New-Item -Path $regPath -Force | Out-Null
    }

    # 4. Crear o editar el valor DWORD
    # Set-ItemProperty crea el valor si no existe, o lo edita si ya existe.
    Set-ItemProperty -Path $regPath -Name $regName -Value $regValue -Type DWORD -Force

    Write-Host "`n[EXITO] Registro actualizado correctamente." -ForegroundColor Green
    Write-Host "Ruta: $regPath"
    Write-Host "Clave: $regName"
    Write-Host "Valor: $regValue"
}
catch {
    Write-Host "`n[ERROR] Ocurrió un error al modificar el registro:" -ForegroundColor Red
    Write-Host $_.Exception.Message
}

Write-Host "`nPresiona Enter para salir..."
Read-Host