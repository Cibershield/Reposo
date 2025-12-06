# Reposo - Mantener Windows Activo

Scripts de PowerShell para evitar que Windows entre en modo reposo/suspensión durante sincronizaciones largas de OneDrive u otras tareas.

## Contenido

| Archivo | Descripción |
|---------|-------------|
| `Mantener-Windows-Activo.ps1` | Script avanzado (usa API de Windows) |
| `Mantener-Windows-Activo-SIMPLE.ps1` | Script simple (más compatible) |
| `EJECUTAR-AQUI.bat` | Menú para elegir versión |
| `EJECUTAR-VERSION-SIMPLE.bat` | Ejecuta versión simple directamente |
| `INSTRUCCIONES.txt` | Instrucciones detalladas |

## Uso Rápido

### Método Recomendado (Sin errores)
1. Haz doble clic en `EJECUTAR-VERSION-SIMPLE.bat`
2. El script mantendrá Windows activo
3. Para detener: Presiona `Ctrl+C`

### Método con Menú
1. Clic derecho en `EJECUTAR-AQUI.bat` → "Ejecutar como administrador"
2. Elige entre versión avanzada o simple
3. Para detener: Presiona `Ctrl+C`

## ¿Cuál versión usar?

### Versión Simple (Recomendada)
- Más compatible
- No requiere permisos de administrador
- Simula actividad con tecla F15 cada minuto (no afecta tu trabajo)

### Versión Avanzada
- Usa API nativa de Windows (`SetThreadExecutionState`)
- Más eficiente
- Requiere permisos de administrador

## Características

- Evita que Windows entre en modo reposo/suspensión
- Mantiene el sistema activo para sincronización de OneDrive
- Monitorea el estado de OneDrive
- Muestra el tiempo transcurrido
- Fácil de detener con `Ctrl+C`

## Requisitos

- Windows 10/11
- PowerShell (incluido en Windows)

## Licencia

Uso libre para propósitos personales y comerciales.
