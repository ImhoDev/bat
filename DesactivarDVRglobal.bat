@echo off
:: ============================================================
:: Script para desactivar GameDVR GLOBALMENTE (Todos los usuarios)
:: Solicita permisos de Administrador automáticamente
:: ============================================================

:: 1. Verificación de permisos de administrador
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"

if '%errorlevel%' NEQ '0' (
    echo Solicitando permisos de administrador...
    goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    exit /b

:gotAdmin
    if exist "%temp%\getadmin.vbs" ( del "%temp%\getadmin.vbs" )
    pushd "%CD%"
    CD /D "%~dp0"

echo.
echo ========================================================
echo Aplicando configuracion para TODOS los usuarios...
echo ========================================================

:: 2. Configurar para el SISTEMA (HKLM - General)
set "KEY_HKLM=HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\GameDVR"
echo Aplicando en HKLM (General)...
reg add "%KEY_HKLM%" /v "AppCaptureEnabled" /t REG_DWORD /d 0 /f

:: 3. Configurar POLITICAS DE GRUPO (HKLM - Policies) - Esto fuerza la restricción
:: Nota: En politicas se suele usar tambien "AllowGameDVR" para bloquearlo totalmente.
set "KEY_POLICY=HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
echo Aplicando en Politicas de Grupo...
reg add "%KEY_POLICY%" /v "AppCaptureEnabled" /t REG_DWORD /d 0 /f
reg add "%KEY_POLICY%" /v "AllowGameDVR" /t REG_DWORD /d 0 /f

:: 4. Configurar para el USUARIO ACTUAL (HKCU) - Para efecto inmediato
set "KEY_HKCU=HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\GameDVR"
echo Aplicando en Usuario Actual...
reg add "%KEY_HKCU%" /v "AppCaptureEnabled" /t REG_DWORD /d 0 /f

echo.
if %errorlevel% EQU 0 (
    echo [EXITO] GameDVR desactivado para todos los usuarios.
) else (
    echo [ERROR] Hubo un problema.
)

echo.
echo Presiona cualquier tecla para salir...
pause >nul