# Script para mantener Windows 11 activo durante sincronizacion de OneDrive
# Presiona Ctrl+C para detener el script

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Mantener Windows Activo" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Este script evitara que Windows entre en reposo" -ForegroundColor Yellow
Write-Host "Presiona Ctrl+C para detener el script" -ForegroundColor Yellow
Write-Host ""

# Definir el codigo C# para la API de Windows
$code = @"
using System;
using System.Runtime.InteropServices;

public class PowerManager {
    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern uint SetThreadExecutionState(uint esFlags);
}
"@

# Importar el codigo C# solo si no existe la clase
if (-not ([System.Management.Automation.PSTypeName]'PowerManager').Type) {
    Add-Type -TypeDefinition $code -Language CSharp
}

# Definir las constantes como uint directamente
[uint32]$ES_CONTINUOUS = 0x80000000
[uint32]$ES_SYSTEM_REQUIRED = 0x00000001
[uint32]$ES_DISPLAY_REQUIRED = 0x00000002

# Combinar las banderas
[uint32]$flags = $ES_CONTINUOUS -bor $ES_SYSTEM_REQUIRED -bor $ES_DISPLAY_REQUIRED

# Evitar que el sistema y la pantalla entren en reposo
$result = [PowerManager]::SetThreadExecutionState($flags)

if ($result -ne 0) {
    Write-Host "Modo reposo desactivado exitosamente" -ForegroundColor Green
} else {
    Write-Host "Error al configurar el modo de energia" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Monitoreando estado de OneDrive..." -ForegroundColor Cyan
Write-Host ""

# Contador de tiempo
$startTime = Get-Date
$counter = 0

try {
    while ($true) {
        $counter++
        $elapsed = (Get-Date) - $startTime
        
        # Verificar estado de OneDrive
        $oneDriveProcess = Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue
        
        if ($oneDriveProcess) {
            $status = "OneDrive esta activo"
            $color = "Green"
        } else {
            $status = "OneDrive no detectado"
            $color = "Yellow"
        }
        
        # Mostrar informacion cada 10 segundos
        if ($counter % 10 -eq 0) {
            Clear-Host
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host "  Mantener Windows Activo" -ForegroundColor Cyan
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Estado: $status" -ForegroundColor $color
            Write-Host "Tiempo transcurrido: $($elapsed.ToString('hh\:mm\:ss'))" -ForegroundColor White
            Write-Host ""
            Write-Host "El sistema NO entrara en reposo" -ForegroundColor Yellow
            Write-Host "Presiona Ctrl+C para detener" -ForegroundColor Yellow
            Write-Host ""
        }
        
        # Esperar 1 segundo
        Start-Sleep -Seconds 1
    }
}
finally {
    # Restaurar configuracion normal al salir
    Write-Host ""
    Write-Host "Restaurando configuracion de energia..." -ForegroundColor Yellow
    [PowerManager]::SetThreadExecutionState($ES_CONTINUOUS)
    Write-Host "Configuracion restaurada. Windows puede entrar en reposo nuevamente." -ForegroundColor Green
}
