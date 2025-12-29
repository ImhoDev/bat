# ============================================================
# Script PowerShell para desactivar GameDVR GLOBALMENTE
# ============================================================

# 1. Verificación de permisos de administrador
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Solicitando permisos de administrador..." -ForegroundColor Yellow
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = "powershell.exe"
    $processInfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $processInfo.Verb = "RunAs"
    [System.Diagnostics.Process]::Start($processInfo)
    Exit
}

Write-Host "Iniciando configuración global..." -ForegroundColor Cyan

# Definimos una lista de claves a modificar para cubrir todos los frentes
$targetKeys = @(
    # 1. Sistema General (HKLM)
    @{ Path = "HKLM:\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "AppCaptureEnabled"; Value = 0 },
    
    # 2. Políticas de Grupo (HKLM Policies) - Fuerza el cambio para todos
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"; Name = "AppCaptureEnabled"; Value = 0 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"; Name = "AllowGameDVR"; Value = 0 },
    
    # 3. Usuario Actual (HKCU)
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"; Name = "AppCaptureEnabled"; Value = 0 }
)

foreach ($item in $targetKeys) {
    try {
        # Verificar si la ruta existe, si no, crearla
        if (-not (Test-Path $item.Path)) {
            Write-Host "Creando ruta: $($item.Path)" -ForegroundColor Yellow
            New-Item -Path $item.Path -Force | Out-Null
        }

        # Establecer el valor
        Set-ItemProperty -Path $item.Path -Name $item.Name -Value $item.Value -Type DWORD -Force
        Write-Host " [OK] Configurado: $($item.Path) -> $($item.Name) = $($item.Value)" -ForegroundColor Green
    }
    catch {
        Write-Host " [X] Error en $($item.Path): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n[COMPLETADO] La configuración se ha aplicado a nivel de sistema y usuario."
Write-Host "Presiona Enter para salir..."
Read-Host