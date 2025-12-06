@echo off
chcp 65001 > nul
echo ========================================
echo   Mantener Windows Activo - OneDrive
echo ========================================
echo.
echo Selecciona la version del script:
echo.
echo 1. Version AVANZADA (API de Windows)
echo 2. Version SIMPLE (Mas compatible)
echo.
set /p opcion="Ingresa tu opcion (1 o 2): "

if "%opcion%"=="1" (
    echo.
    echo Ejecutando version avanzada...
    PowerShell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Mantener-Windows-Activo.ps1"
) else if "%opcion%"=="2" (
    echo.
    echo Ejecutando version simple...
    PowerShell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Mantener-Windows-Activo-SIMPLE.ps1"
) else (
    echo.
    echo Opcion invalida. Ejecutando version simple por defecto...
    timeout /t 2 > nul
    PowerShell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Mantener-Windows-Activo-SIMPLE.ps1"
)

echo.
echo Script finalizado.
pause
