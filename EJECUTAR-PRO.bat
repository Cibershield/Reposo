@echo off
chcp 65001 >nul 2>&1
title Reposo Pro - Mantener Windows Activo

echo.
echo   ╔═══════════════════════════════════════════════════════════╗
echo   ║               REPOSO PRO - Version Avanzada               ║
echo   ╚═══════════════════════════════════════════════════════════╝
echo.

:: Verificar si PowerShell esta disponible
where powershell >nul 2>&1
if %errorlevel% neq 0 (
    echo   [ERROR] PowerShell no encontrado en el sistema.
    pause
    exit /b 1
)

:: Obtener la ruta del script
set "SCRIPT_PATH=%~dp0Reposo-Pro.ps1"

:: Verificar si el script existe
if not exist "%SCRIPT_PATH%" (
    echo   [ERROR] No se encontro Reposo-Pro.ps1
    echo   Asegurate de que el archivo este en la misma carpeta.
    pause
    exit /b 1
)

echo   Iniciando Reposo Pro...
echo   ─────────────────────────────────────────────────────────────
echo.

:: Ejecutar con politica de ejecucion bypass
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PATH%"

echo.
echo   ─────────────────────────────────────────────────────────────
echo   Reposo Pro ha finalizado.
echo.
pause
