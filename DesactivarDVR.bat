@echo off
:: ============================================================
:: Script para desactivar GameDVR en el Registro de Windows
:: Solicita permisos de Administrador automáticamente
:: ============================================================

:: 1. Verificación de permisos de administrador
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"

:: Si hay error, no somos admin. Solicitamos elevación.
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

:: 2. Modificación del Registro
echo.
echo ========================================================
echo Configurando GameDVR en el registro...
echo ========================================================

:: Definir ruta y clave
set "REG_PATH=HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\GameDVR"
set "REG_NAME=AppCaptureEnabled"
set "REG_VALUE=0"

:: Comando REG ADD
:: /f = fuerza la sobrescritura sin preguntar
:: /v = nombre del valor
:: /t = tipo de dato (REG_DWORD)
:: /d = datos (0)

reg add "%REG_PATH%" /v "%REG_NAME%" /t REG_DWORD /d %REG_VALUE% /f

if %errorlevel% EQU 0 (
    echo.
    echo [EXITO] El registro se ha actualizado correctamente.
    echo Valor: %REG_NAME% = %REG_VALUE%
) else (
    echo.
    echo [ERROR] Hubo un problema al escribir en el registro.
)

echo.
echo Presiona cualquier tecla para salir...
pause >nul