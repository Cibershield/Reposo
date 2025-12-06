# Reposo - Mantener Windows Activo

Scripts de PowerShell para evitar que Windows entre en modo reposo/suspensión durante sincronizaciones largas de OneDrive u otras tareas.

## Contenido

| Archivo | Descripción |
|---------|-------------|
| `Reposo-Pro.ps1` | **NUEVO** Script PRO con todas las funciones avanzadas |
| `EJECUTAR-PRO.bat` | **NUEVO** Ejecuta la versión PRO |
| `Reposo-Config.json` | **NUEVO** Archivo de configuración |
| `Mantener-Windows-Activo.ps1` | Script avanzado (usa API de Windows) |
| `Mantener-Windows-Activo-SIMPLE.ps1` | Script simple (más compatible) |
| `EJECUTAR-AQUI.bat` | Menú para elegir versión clásica |
| `EJECUTAR-VERSION-SIMPLE.bat` | Ejecuta versión simple directamente |
| `INSTRUCCIONES.txt` | Instrucciones detalladas |

---

## Reposo Pro (v2.0) - Nueva Versión

La versión PRO incluye todas las funcionalidades avanzadas:

### Temporizador y Programación
- Configurar tiempo máximo de ejecución (ej: 4 horas)
- Apagado automático cuando OneDrive termine de sincronizar
- Programar inicio/fin en horarios específicos (ej: 22:00 a 06:00)

### Notificaciones
- Alertas de Windows cuando OneDrive termine
- Notificaciones por Telegram (configurable)
- Sonido de alerta al finalizar

### Monitoreo Avanzado
- Velocidad de sincronización de OneDrive en tiempo real
- Conteo de archivos
- Log de actividad guardado en archivo

### Modos de Energía
- **Normal**: Sistema y pantalla activos
- **Pantalla Apagada**: Sistema activo, pantalla puede apagarse
- **Nocturno**: Sistema activo, pantalla apagada inmediatamente
- Opción para reducir brillo automáticamente

### Uso de Reposo Pro

```
1. Haz doble clic en EJECUTAR-PRO.bat
2. Configura las opciones en el menú interactivo
3. Selecciona "1" para iniciar el monitoreo
4. Presiona Ctrl+C para detener
```

### Configuración por Archivo

Puedes editar `Reposo-Config.json` para preconfigurar:

```json
{
    "TiempoMaximoHoras": 4,
    "HoraInicio": "22:00",
    "HoraFin": "06:00",
    "ApagadoAutoSincronizacion": true,
    "NotificacionWindows": true,
    "NotificacionSonido": true,
    "NotificacionTelegram": false,
    "TelegramBotToken": "tu-token-aqui",
    "TelegramChatId": "tu-chat-id",
    "ModoEnergia": "Nocturno",
    "ReducirBrillo": true,
    "NivelBrilloReducido": 20
}
```

### Configurar Telegram (Opcional)

1. Crea un bot con [@BotFather](https://t.me/botfather) en Telegram
2. Copia el token del bot
3. Obtén tu Chat ID enviando un mensaje a [@userinfobot](https://t.me/userinfobot)
4. Configura los valores en el menú o en `Reposo-Config.json`

---

## Versión Clásica

### Uso Rápido

#### Método Recomendado (Sin errores)
1. Haz doble clic en `EJECUTAR-VERSION-SIMPLE.bat`
2. El script mantendrá Windows activo
3. Para detener: Presiona `Ctrl+C`

#### Método con Menú
1. Clic derecho en `EJECUTAR-AQUI.bat` → "Ejecutar como administrador"
2. Elige entre versión avanzada o simple
3. Para detener: Presiona `Ctrl+C`

### ¿Cuál versión usar?

#### Versión Simple (Recomendada para principiantes)
- Más compatible
- No requiere permisos de administrador
- Simula actividad con tecla F15 cada minuto

#### Versión Avanzada
- Usa API nativa de Windows (`SetThreadExecutionState`)
- Más eficiente
- Requiere permisos de administrador

---

## Características Generales

- Evita que Windows entre en modo reposo/suspensión
- Mantiene el sistema activo para sincronización de OneDrive
- Monitorea el estado de OneDrive
- Muestra el tiempo transcurrido
- Fácil de detener con `Ctrl+C`

## Requisitos

- Windows 10/11
- PowerShell 5.1 o superior (incluido en Windows)

## Licencia

Uso libre para propósitos personales y comerciales.

---

Desarrollado por [Cibershield](https://github.com/Cibershield)
