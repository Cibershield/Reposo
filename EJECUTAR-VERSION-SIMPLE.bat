@echo off
chcp 65001 > nul
echo ========================================
echo   Version SIMPLE - Mantener Windows Activo
echo ========================================
echo.
echo Esta es la version mas compatible
echo No requiere permisos de administrador
echo.
echo Presiona cualquier tecla para continuar...
pause > nul

PowerShell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Mantener-Windows-Activo-SIMPLE.ps1"

echo.
echo Script finalizado.
pause
