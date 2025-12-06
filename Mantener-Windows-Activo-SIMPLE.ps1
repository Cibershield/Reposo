# Script ALTERNATIVO para mantener Windows activo
# Version simple usando metodo de simulacion de teclado
# Presiona Ctrl+C para detener el script

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Mantener Windows Activo (SIMPLE)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Este script mantendra Windows activo" -ForegroundColor Yellow
Write-Host "simulando actividad minima del sistema" -ForegroundColor Yellow
Write-Host ""
Write-Host "Presiona Ctrl+C para detener el script" -ForegroundColor Yellow
Write-Host ""

# Cargar ensamblado para simulacion de teclado
Add-Type -AssemblyName System.Windows.Forms

Write-Host "Script iniciado correctamente" -ForegroundColor Green
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
        
        # Cada 60 segundos, simular presion de tecla F15 (no hace nada visible)
        if ($counter % 60 -eq 0) {
            [System.Windows.Forms.SendKeys]::SendWait("{F15}")
        }
        
        # Mostrar informacion cada 10 segundos
        if ($counter % 10 -eq 0) {
            Clear-Host
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host "  Mantener Windows Activo (SIMPLE)" -ForegroundColor Cyan
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Estado: $status" -ForegroundColor $color
            Write-Host "Tiempo transcurrido: $($elapsed.ToString('hh\:mm\:ss'))" -ForegroundColor White
            Write-Host ""
            Write-Host "El sistema NO entrara en reposo" -ForegroundColor Yellow
            Write-Host "Presiona Ctrl+C para detener" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Metodo: Simulacion de actividad (F15)" -ForegroundColor Gray
        }
        
        # Esperar 1 segundo
        Start-Sleep -Seconds 1
    }
}
finally {
    Write-Host ""
    Write-Host "Script detenido. Windows volvera a su configuracion normal." -ForegroundColor Green
}
