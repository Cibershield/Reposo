#Requires -Version 5.1
<#
.SYNOPSIS
    Reposo Pro - Mantener Windows Activo con Funciones Avanzadas
.DESCRIPTION
    Script avanzado para mantener Windows activo durante sincronizaciones.
    Incluye temporizador, notificaciones, monitoreo y modos de energia.
.AUTHOR
    Cibershield
.VERSION
    2.0.0
#>

param(
    [string]$ConfigFile = ""
)

# ============================================================
# CONFIGURACION POR DEFECTO
# ============================================================
$Script:Config = @{
    # Temporizador
    TiempoMaximoHoras = 0              # 0 = sin limite
    HoraInicio = ""                     # Formato "HH:mm" o vacio para iniciar inmediatamente
    HoraFin = ""                        # Formato "HH:mm" o vacio para sin limite
    ApagadoAutoSincronizacion = $true   # Apagar cuando OneDrive termine

    # Notificaciones
    NotificacionWindows = $true
    NotificacionSonido = $true
    NotificacionTelegram = $false
    TelegramBotToken = ""
    TelegramChatId = ""

    # Monitoreo
    IntervaloSegundos = 60
    GuardarLog = $true
    ArchivoLog = "Reposo-Log.txt"

    # Energia
    ModoEnergia = "Normal"              # Normal, PantallaApagada, Nocturno
    ReducirBrillo = $false
    NivelBrilloReducido = 20            # Porcentaje (0-100)
}

# ============================================================
# VARIABLES GLOBALES
# ============================================================
$Script:TiempoInicio = Get-Date
$Script:UltimoEstadoOneDrive = ""
$Script:ArchivosAnteriores = 0
$Script:BytesAnteriores = 0
$Script:TiempoUltimaLectura = Get-Date
$Script:Ejecutando = $true
$Script:LogPath = ""

# ============================================================
# FUNCIONES DE API DE WINDOWS
# ============================================================
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class PowerManager {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern uint SetThreadExecutionState(uint esFlags);

    public const uint ES_CONTINUOUS = 0x80000000;
    public const uint ES_SYSTEM_REQUIRED = 0x00000001;
    public const uint ES_DISPLAY_REQUIRED = 0x00000002;
    public const uint ES_AWAYMODE_REQUIRED = 0x00000040;
}

public class BrightnessControl {
    [DllImport("user32.dll")]
    public static extern IntPtr GetDC(IntPtr hWnd);

    [DllImport("gdi32.dll")]
    public static extern bool SetDeviceGammaRamp(IntPtr hDC, ref RAMP lpRamp);

    [DllImport("gdi32.dll")]
    public static extern bool GetDeviceGammaRamp(IntPtr hDC, ref RAMP lpRamp);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
    public struct RAMP {
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 256)]
        public ushort[] Red;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 256)]
        public ushort[] Green;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 256)]
        public ushort[] Blue;
    }
}

public class ScreenControl {
    [DllImport("user32.dll")]
    public static extern int SendMessage(int hWnd, int hMsg, int wParam, int lParam);

    public const int HWND_BROADCAST = 0xFFFF;
    public const int WM_SYSCOMMAND = 0x0112;
    public const int SC_MONITORPOWER = 0xF170;
    public const int MONITOR_OFF = 2;
    public const int MONITOR_ON = -1;
}
"@

# ============================================================
# FUNCIONES DE LOG
# ============================================================
function Write-Log {
    param([string]$Mensaje, [string]$Tipo = "INFO")

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $linea = "[$timestamp] [$Tipo] $Mensaje"

    # Mostrar en consola con colores
    switch ($Tipo) {
        "INFO"    { Write-Host $linea -ForegroundColor Cyan }
        "OK"      { Write-Host $linea -ForegroundColor Green }
        "WARN"    { Write-Host $linea -ForegroundColor Yellow }
        "ERROR"   { Write-Host $linea -ForegroundColor Red }
        "SYNC"    { Write-Host $linea -ForegroundColor Magenta }
        default   { Write-Host $linea }
    }

    # Guardar en archivo si esta habilitado
    if ($Script:Config.GuardarLog -and $Script:LogPath) {
        Add-Content -Path $Script:LogPath -Value $linea -ErrorAction SilentlyContinue
    }
}

# ============================================================
# FUNCIONES DE NOTIFICACION
# ============================================================
function Send-NotificacionWindows {
    param([string]$Titulo, [string]$Mensaje)

    if (-not $Script:Config.NotificacionWindows) { return }

    try {
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

        $template = @"
<toast>
    <visual>
        <binding template="ToastText02">
            <text id="1">$Titulo</text>
            <text id="2">$Mensaje</text>
        </binding>
    </visual>
    <audio src="ms-winsoundevent:Notification.Default"/>
</toast>
"@
        $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
        $xml.LoadXml($template)
        $toast = New-Object Windows.UI.Notifications.ToastNotification $xml
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Reposo Pro").Show($toast)
    }
    catch {
        # Fallback: usar BurntToast si esta disponible o mensaje simple
        try {
            Add-Type -AssemblyName System.Windows.Forms
            $balloon = New-Object System.Windows.Forms.NotifyIcon
            $balloon.Icon = [System.Drawing.SystemIcons]::Information
            $balloon.BalloonTipTitle = $Titulo
            $balloon.BalloonTipText = $Mensaje
            $balloon.Visible = $true
            $balloon.ShowBalloonTip(5000)
            Start-Sleep -Seconds 5
            $balloon.Dispose()
        }
        catch {
            Write-Log "No se pudo mostrar notificacion de Windows" "WARN"
        }
    }
}

function Send-NotificacionSonido {
    if (-not $Script:Config.NotificacionSonido) { return }

    try {
        [System.Media.SystemSounds]::Exclamation.Play()
    }
    catch {
        [Console]::Beep(800, 500)
    }
}

function Send-NotificacionTelegram {
    param([string]$Mensaje)

    if (-not $Script:Config.NotificacionTelegram) { return }
    if ([string]::IsNullOrEmpty($Script:Config.TelegramBotToken)) { return }
    if ([string]::IsNullOrEmpty($Script:Config.TelegramChatId)) { return }

    try {
        $url = "https://api.telegram.org/bot$($Script:Config.TelegramBotToken)/sendMessage"
        $body = @{
            chat_id = $Script:Config.TelegramChatId
            text = "🖥️ Reposo Pro`n$Mensaje"
            parse_mode = "HTML"
        }
        Invoke-RestMethod -Uri $url -Method Post -Body $body -ErrorAction SilentlyContinue | Out-Null
        Write-Log "Notificacion Telegram enviada" "OK"
    }
    catch {
        Write-Log "Error enviando notificacion Telegram: $_" "WARN"
    }
}

function Send-TodasNotificaciones {
    param([string]$Titulo, [string]$Mensaje)

    Send-NotificacionWindows -Titulo $Titulo -Mensaje $Mensaje
    Send-NotificacionSonido
    Send-NotificacionTelegram -Mensaje "$Titulo`n$Mensaje"
}

# ============================================================
# FUNCIONES DE ONEDRIVE
# ============================================================
function Get-OneDriveStatus {
    $resultado = @{
        Ejecutando = $false
        Estado = "Desconocido"
        ArchivosPendientes = 0
        Sincronizando = $false
        RutaOneDrive = ""
    }

    # Verificar si OneDrive esta ejecutandose
    $proceso = Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue
    if ($proceso) {
        $resultado.Ejecutando = $true
    }

    # Obtener ruta de OneDrive
    $rutasOneDrive = @(
        "$env:USERPROFILE\OneDrive",
        "$env:USERPROFILE\OneDrive - Personal",
        (Get-ItemProperty -Path "HKCU:\Software\Microsoft\OneDrive" -Name "UserFolder" -ErrorAction SilentlyContinue).UserFolder
    ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

    if ($rutasOneDrive) {
        $resultado.RutaOneDrive = $rutasOneDrive
    }

    # Intentar obtener estado detallado via COM
    try {
        $odStatus = Get-ItemProperty -Path "HKCU:\Software\Microsoft\OneDrive\Accounts\Personal" -ErrorAction SilentlyContinue
        if ($odStatus) {
            # Contar archivos en sincronizacion
            if ($resultado.RutaOneDrive) {
                $archivosTemp = Get-ChildItem -Path $resultado.RutaOneDrive -Recurse -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -match "\.tmp$|~\$" }
                $resultado.ArchivosPendientes = ($archivosTemp | Measure-Object).Count
            }
        }
    }
    catch { }

    # Determinar estado
    if (-not $resultado.Ejecutando) {
        $resultado.Estado = "No ejecutando"
    }
    elseif ($resultado.ArchivosPendientes -gt 0) {
        $resultado.Estado = "Sincronizando"
        $resultado.Sincronizando = $true
    }
    else {
        $resultado.Estado = "Sincronizado"
    }

    return $resultado
}

function Get-OneDriveSyncSpeed {
    param([string]$RutaOneDrive)

    if (-not $RutaOneDrive -or -not (Test-Path $RutaOneDrive)) {
        return @{ Velocidad = "N/A"; BytesPorSegundo = 0 }
    }

    try {
        $archivos = Get-ChildItem -Path $RutaOneDrive -Recurse -File -ErrorAction SilentlyContinue
        $totalBytes = ($archivos | Measure-Object -Property Length -Sum).Sum
        $totalArchivos = ($archivos | Measure-Object).Count

        $tiempoActual = Get-Date
        $diferenciaTiempo = ($tiempoActual - $Script:TiempoUltimaLectura).TotalSeconds

        if ($diferenciaTiempo -gt 0 -and $Script:BytesAnteriores -gt 0) {
            $bytesDiferencia = $totalBytes - $Script:BytesAnteriores
            $velocidadBps = [math]::Abs($bytesDiferencia / $diferenciaTiempo)

            # Formatear velocidad
            if ($velocidadBps -gt 1MB) {
                $velocidadStr = "{0:N2} MB/s" -f ($velocidadBps / 1MB)
            }
            elseif ($velocidadBps -gt 1KB) {
                $velocidadStr = "{0:N2} KB/s" -f ($velocidadBps / 1KB)
            }
            else {
                $velocidadStr = "{0:N0} B/s" -f $velocidadBps
            }
        }
        else {
            $velocidadStr = "Calculando..."
            $velocidadBps = 0
        }

        # Actualizar valores anteriores
        $Script:BytesAnteriores = $totalBytes
        $Script:ArchivosAnteriores = $totalArchivos
        $Script:TiempoUltimaLectura = $tiempoActual

        return @{
            Velocidad = $velocidadStr
            BytesPorSegundo = $velocidadBps
            TotalArchivos = $totalArchivos
            TotalBytes = $totalBytes
        }
    }
    catch {
        return @{ Velocidad = "Error"; BytesPorSegundo = 0 }
    }
}

# ============================================================
# FUNCIONES DE ENERGIA
# ============================================================
function Set-ModoEnergia {
    param([string]$Modo)

    switch ($Modo) {
        "Normal" {
            # Mantener sistema y pantalla activos
            [PowerManager]::SetThreadExecutionState(
                [PowerManager]::ES_CONTINUOUS -bor
                [PowerManager]::ES_SYSTEM_REQUIRED -bor
                [PowerManager]::ES_DISPLAY_REQUIRED
            ) | Out-Null
            Write-Log "Modo energia: Normal (sistema y pantalla activos)" "OK"
        }
        "PantallaApagada" {
            # Mantener sistema activo, permitir apagar pantalla
            [PowerManager]::SetThreadExecutionState(
                [PowerManager]::ES_CONTINUOUS -bor
                [PowerManager]::ES_SYSTEM_REQUIRED
            ) | Out-Null
            Write-Log "Modo energia: Pantalla puede apagarse" "OK"
        }
        "Nocturno" {
            # Modo nocturno: sistema activo, pantalla apagada
            [PowerManager]::SetThreadExecutionState(
                [PowerManager]::ES_CONTINUOUS -bor
                [PowerManager]::ES_SYSTEM_REQUIRED -bor
                [PowerManager]::ES_AWAYMODE_REQUIRED
            ) | Out-Null
            # Apagar pantalla
            Start-Sleep -Seconds 2
            [ScreenControl]::SendMessage([ScreenControl]::HWND_BROADCAST, [ScreenControl]::WM_SYSCOMMAND, [ScreenControl]::SC_MONITORPOWER, [ScreenControl]::MONITOR_OFF) | Out-Null
            Write-Log "Modo energia: Nocturno (pantalla apagada)" "OK"
        }
    }
}

function Set-Brillo {
    param([int]$Porcentaje)

    try {
        # Metodo WMI para laptops
        $brightness = Get-WmiObject -Namespace root/WMI -Class WmiMonitorBrightnessMethods -ErrorAction SilentlyContinue
        if ($brightness) {
            $brightness.WmiSetBrightness(1, $Porcentaje)
            Write-Log "Brillo ajustado a $Porcentaje%" "OK"
            return $true
        }
    }
    catch { }

    try {
        # Metodo alternativo via PowerShell
        (Get-WmiObject -Namespace root/WMI -Class WmiMonitorBrightnessMethods).WmiSetBrightness(1, $Porcentaje)
        return $true
    }
    catch {
        Write-Log "No se pudo ajustar el brillo (puede no ser compatible)" "WARN"
        return $false
    }
}

function Reset-ModoEnergia {
    [PowerManager]::SetThreadExecutionState([PowerManager]::ES_CONTINUOUS) | Out-Null

    # Encender pantalla si estaba apagada
    [ScreenControl]::SendMessage([ScreenControl]::HWND_BROADCAST, [ScreenControl]::WM_SYSCOMMAND, [ScreenControl]::SC_MONITORPOWER, [ScreenControl]::MONITOR_ON) | Out-Null
}

# ============================================================
# FUNCIONES DE TEMPORIZADOR
# ============================================================
function Test-DentroDeHorario {
    if ([string]::IsNullOrEmpty($Script:Config.HoraInicio) -and [string]::IsNullOrEmpty($Script:Config.HoraFin)) {
        return $true
    }

    $ahora = Get-Date

    if (-not [string]::IsNullOrEmpty($Script:Config.HoraInicio)) {
        $horaInicio = [DateTime]::ParseExact($Script:Config.HoraInicio, "HH:mm", $null)
        if ($ahora.TimeOfDay -lt $horaInicio.TimeOfDay) {
            return $false
        }
    }

    if (-not [string]::IsNullOrEmpty($Script:Config.HoraFin)) {
        $horaFin = [DateTime]::ParseExact($Script:Config.HoraFin, "HH:mm", $null)
        if ($ahora.TimeOfDay -gt $horaFin.TimeOfDay) {
            return $false
        }
    }

    return $true
}

function Test-TiempoMaximoAlcanzado {
    if ($Script:Config.TiempoMaximoHoras -le 0) {
        return $false
    }

    $tiempoTranscurrido = (Get-Date) - $Script:TiempoInicio
    return ($tiempoTranscurrido.TotalHours -ge $Script:Config.TiempoMaximoHoras)
}

function Get-TiempoRestante {
    if ($Script:Config.TiempoMaximoHoras -le 0) {
        return "Sin limite"
    }

    $tiempoTranscurrido = (Get-Date) - $Script:TiempoInicio
    $tiempoRestante = [TimeSpan]::FromHours($Script:Config.TiempoMaximoHoras) - $tiempoTranscurrido

    if ($tiempoRestante.TotalSeconds -le 0) {
        return "Finalizado"
    }

    return "{0:hh\:mm\:ss}" -f $tiempoRestante
}

function Get-TiempoTranscurrido {
    $tiempoTranscurrido = (Get-Date) - $Script:TiempoInicio
    return "{0:hh\:mm\:ss}" -f $tiempoTranscurrido
}

# ============================================================
# FUNCIONES DE CONFIGURACION
# ============================================================
function Import-Configuracion {
    param([string]$Path)

    if ([string]::IsNullOrEmpty($Path) -or -not (Test-Path $Path)) {
        return
    }

    try {
        $configJson = Get-Content -Path $Path -Raw | ConvertFrom-Json

        foreach ($prop in $configJson.PSObject.Properties) {
            if ($Script:Config.ContainsKey($prop.Name)) {
                $Script:Config[$prop.Name] = $prop.Value
            }
        }

        Write-Log "Configuracion cargada desde: $Path" "OK"
    }
    catch {
        Write-Log "Error cargando configuracion: $_" "ERROR"
    }
}

function Export-ConfiguracionEjemplo {
    $configPath = Join-Path (Split-Path $PSScriptRoot) "Reposo-Config.json"
    $Script:Config | ConvertTo-Json -Depth 3 | Set-Content -Path $configPath
    Write-Log "Configuracion de ejemplo guardada en: $configPath" "OK"
}

# ============================================================
# INTERFAZ DE USUARIO
# ============================================================
function Show-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║                                                           ║" -ForegroundColor Cyan
    Write-Host "  ║   ██████╗ ███████╗██████╗  ██████╗ ███████╗ ██████╗       ║" -ForegroundColor Cyan
    Write-Host "  ║   ██╔══██╗██╔════╝██╔══██╗██╔═══██╗██╔════╝██╔═══██╗      ║" -ForegroundColor Cyan
    Write-Host "  ║   ██████╔╝█████╗  ██████╔╝██║   ██║███████╗██║   ██║      ║" -ForegroundColor Cyan
    Write-Host "  ║   ██╔══██╗██╔══╝  ██╔═══╝ ██║   ██║╚════██║██║   ██║      ║" -ForegroundColor Cyan
    Write-Host "  ║   ██║  ██║███████╗██║     ╚██████╔╝███████║╚██████╔╝      ║" -ForegroundColor Cyan
    Write-Host "  ║   ╚═╝  ╚═╝╚══════╝╚═╝      ╚═════╝ ╚══════╝ ╚═════╝       ║" -ForegroundColor Cyan
    Write-Host "  ║                      PRO v2.0                             ║" -ForegroundColor Yellow
    Write-Host "  ║                                                           ║" -ForegroundColor Cyan
    Write-Host "  ╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Mantener Windows Activo - Version Avanzada" -ForegroundColor White
    Write-Host "  Presiona Ctrl+C para detener" -ForegroundColor Gray
    Write-Host ""
}

function Show-Menu {
    Write-Host ""
    Write-Host "  ┌─────────────────────────────────────────┐" -ForegroundColor White
    Write-Host "  │         CONFIGURACION RAPIDA            │" -ForegroundColor White
    Write-Host "  ├─────────────────────────────────────────┤" -ForegroundColor White
    Write-Host "  │  1. Iniciar con configuracion actual    │" -ForegroundColor Green
    Write-Host "  │  2. Configurar temporizador             │" -ForegroundColor Yellow
    Write-Host "  │  3. Configurar notificaciones           │" -ForegroundColor Yellow
    Write-Host "  │  4. Configurar modo de energia          │" -ForegroundColor Yellow
    Write-Host "  │  5. Cargar configuracion desde archivo  │" -ForegroundColor Cyan
    Write-Host "  │  6. Guardar configuracion actual        │" -ForegroundColor Cyan
    Write-Host "  │  7. Salir                               │" -ForegroundColor Red
    Write-Host "  └─────────────────────────────────────────┘" -ForegroundColor White
    Write-Host ""
}

function Show-ConfiguracionActual {
    Write-Host ""
    Write-Host "  ┌─────────────────────────────────────────┐" -ForegroundColor Cyan
    Write-Host "  │       CONFIGURACION ACTUAL              │" -ForegroundColor Cyan
    Write-Host "  ├─────────────────────────────────────────┤" -ForegroundColor Cyan

    $tiempoMax = if ($Script:Config.TiempoMaximoHoras -eq 0) { "Sin limite" } else { "$($Script:Config.TiempoMaximoHoras) horas" }
    $horaInicio = if ([string]::IsNullOrEmpty($Script:Config.HoraInicio)) { "Inmediato" } else { $Script:Config.HoraInicio }
    $horaFin = if ([string]::IsNullOrEmpty($Script:Config.HoraFin)) { "Sin limite" } else { $Script:Config.HoraFin }

    Write-Host "  │  Tiempo maximo: $tiempoMax" -ForegroundColor White
    Write-Host "  │  Hora inicio: $horaInicio" -ForegroundColor White
    Write-Host "  │  Hora fin: $horaFin" -ForegroundColor White
    Write-Host "  │  Apagado auto sync: $($Script:Config.ApagadoAutoSincronizacion)" -ForegroundColor White
    Write-Host "  │  Modo energia: $($Script:Config.ModoEnergia)" -ForegroundColor White
    Write-Host "  │  Notif. Windows: $($Script:Config.NotificacionWindows)" -ForegroundColor White
    Write-Host "  │  Notif. Sonido: $($Script:Config.NotificacionSonido)" -ForegroundColor White
    Write-Host "  │  Notif. Telegram: $($Script:Config.NotificacionTelegram)" -ForegroundColor White
    Write-Host "  │  Guardar Log: $($Script:Config.GuardarLog)" -ForegroundColor White
    Write-Host "  └─────────────────────────────────────────┘" -ForegroundColor Cyan
    Write-Host ""
}

function Set-ConfiguracionTemporizador {
    Write-Host ""
    Write-Host "  CONFIGURAR TEMPORIZADOR" -ForegroundColor Yellow
    Write-Host "  ─────────────────────────" -ForegroundColor Yellow

    $input = Read-Host "  Tiempo maximo en horas (0 = sin limite) [$($Script:Config.TiempoMaximoHoras)]"
    if ($input -ne "") { $Script:Config.TiempoMaximoHoras = [int]$input }

    $input = Read-Host "  Hora de inicio (HH:mm, vacio = inmediato) [$($Script:Config.HoraInicio)]"
    if ($input -ne "") { $Script:Config.HoraInicio = $input }

    $input = Read-Host "  Hora de fin (HH:mm, vacio = sin limite) [$($Script:Config.HoraFin)]"
    if ($input -ne "") { $Script:Config.HoraFin = $input }

    $input = Read-Host "  Apagar cuando OneDrive termine? (S/N) [$(if($Script:Config.ApagadoAutoSincronizacion){'S'}else{'N'})]"
    if ($input -ne "") { $Script:Config.ApagadoAutoSincronizacion = ($input -eq "S" -or $input -eq "s") }

    Write-Host "  Configuracion de temporizador actualizada" -ForegroundColor Green
}

function Set-ConfiguracionNotificaciones {
    Write-Host ""
    Write-Host "  CONFIGURAR NOTIFICACIONES" -ForegroundColor Yellow
    Write-Host "  ──────────────────────────" -ForegroundColor Yellow

    $input = Read-Host "  Notificaciones de Windows? (S/N) [$(if($Script:Config.NotificacionWindows){'S'}else{'N'})]"
    if ($input -ne "") { $Script:Config.NotificacionWindows = ($input -eq "S" -or $input -eq "s") }

    $input = Read-Host "  Notificacion con sonido? (S/N) [$(if($Script:Config.NotificacionSonido){'S'}else{'N'})]"
    if ($input -ne "") { $Script:Config.NotificacionSonido = ($input -eq "S" -or $input -eq "s") }

    $input = Read-Host "  Notificaciones por Telegram? (S/N) [$(if($Script:Config.NotificacionTelegram){'S'}else{'N'})]"
    if ($input -ne "") {
        $Script:Config.NotificacionTelegram = ($input -eq "S" -or $input -eq "s")

        if ($Script:Config.NotificacionTelegram) {
            $input = Read-Host "  Token del Bot de Telegram [$($Script:Config.TelegramBotToken)]"
            if ($input -ne "") { $Script:Config.TelegramBotToken = $input }

            $input = Read-Host "  Chat ID de Telegram [$($Script:Config.TelegramChatId)]"
            if ($input -ne "") { $Script:Config.TelegramChatId = $input }
        }
    }

    Write-Host "  Configuracion de notificaciones actualizada" -ForegroundColor Green
}

function Set-ConfiguracionEnergia {
    Write-Host ""
    Write-Host "  CONFIGURAR MODO DE ENERGIA" -ForegroundColor Yellow
    Write-Host "  ───────────────────────────" -ForegroundColor Yellow
    Write-Host "  1. Normal (sistema y pantalla activos)" -ForegroundColor White
    Write-Host "  2. Pantalla Apagada (sistema activo, pantalla puede apagarse)" -ForegroundColor White
    Write-Host "  3. Nocturno (sistema activo, pantalla apagada inmediatamente)" -ForegroundColor White

    $input = Read-Host "  Selecciona modo (1-3)"
    switch ($input) {
        "1" { $Script:Config.ModoEnergia = "Normal" }
        "2" { $Script:Config.ModoEnergia = "PantallaApagada" }
        "3" { $Script:Config.ModoEnergia = "Nocturno" }
    }

    $input = Read-Host "  Reducir brillo automaticamente? (S/N) [$(if($Script:Config.ReducirBrillo){'S'}else{'N'})]"
    if ($input -ne "") {
        $Script:Config.ReducirBrillo = ($input -eq "S" -or $input -eq "s")

        if ($Script:Config.ReducirBrillo) {
            $input = Read-Host "  Nivel de brillo (0-100) [$($Script:Config.NivelBrilloReducido)]"
            if ($input -ne "") { $Script:Config.NivelBrilloReducido = [int]$input }
        }
    }

    Write-Host "  Configuracion de energia actualizada" -ForegroundColor Green
}

# ============================================================
# BUCLE PRINCIPAL
# ============================================================
function Start-MonitoreoActivo {
    # Inicializar log
    if ($Script:Config.GuardarLog) {
        $Script:LogPath = Join-Path $PSScriptRoot $Script:Config.ArchivoLog
        Write-Log "=== Sesion iniciada ===" "INFO"
    }

    # Esperar hora de inicio si esta configurada
    if (-not [string]::IsNullOrEmpty($Script:Config.HoraInicio)) {
        $horaInicio = [DateTime]::ParseExact($Script:Config.HoraInicio, "HH:mm", $null)
        $ahora = Get-Date

        if ($ahora.TimeOfDay -lt $horaInicio.TimeOfDay) {
            Write-Log "Esperando hasta las $($Script:Config.HoraInicio) para iniciar..." "INFO"

            while ((Get-Date).TimeOfDay -lt $horaInicio.TimeOfDay) {
                Start-Sleep -Seconds 30
            }
        }
    }

    # Configurar modo de energia
    Set-ModoEnergia -Modo $Script:Config.ModoEnergia

    # Reducir brillo si esta configurado
    if ($Script:Config.ReducirBrillo) {
        Set-Brillo -Porcentaje $Script:Config.NivelBrilloReducido
    }

    Send-TodasNotificaciones -Titulo "Reposo Pro Iniciado" -Mensaje "El sistema se mantendra activo"

    $Script:TiempoInicio = Get-Date
    $ultimoEstadoSync = $true

    Write-Host ""
    Write-Host "  ┌─────────────────────────────────────────────────────────────┐" -ForegroundColor Green
    Write-Host "  │                    MONITOREO ACTIVO                         │" -ForegroundColor Green
    Write-Host "  └─────────────────────────────────────────────────────────────┘" -ForegroundColor Green
    Write-Host ""

    while ($Script:Ejecutando) {
        # Verificar tiempo maximo
        if (Test-TiempoMaximoAlcanzado) {
            Write-Log "Tiempo maximo alcanzado. Deteniendo..." "WARN"
            Send-TodasNotificaciones -Titulo "Tiempo Maximo" -Mensaje "Se alcanzo el tiempo maximo configurado"
            break
        }

        # Verificar horario
        if (-not (Test-DentroDeHorario)) {
            Write-Log "Fuera de horario programado. Deteniendo..." "WARN"
            Send-TodasNotificaciones -Titulo "Fuera de Horario" -Mensaje "El horario programado ha terminado"
            break
        }

        # Obtener estado de OneDrive
        $estadoOneDrive = Get-OneDriveStatus
        $velocidad = Get-OneDriveSyncSpeed -RutaOneDrive $estadoOneDrive.RutaOneDrive

        # Detectar fin de sincronizacion
        if ($Script:Config.ApagadoAutoSincronizacion) {
            if ($ultimoEstadoSync -and -not $estadoOneDrive.Sincronizando -and $estadoOneDrive.Ejecutando) {
                Write-Log "OneDrive ha terminado de sincronizar!" "OK"
                Send-TodasNotificaciones -Titulo "Sincronizacion Completa" -Mensaje "OneDrive ha terminado de sincronizar todos los archivos"

                # Esperar un poco para confirmar
                Start-Sleep -Seconds 30
                $estadoOneDrive2 = Get-OneDriveStatus
                if (-not $estadoOneDrive2.Sincronizando) {
                    Write-Log "Confirmado: sincronizacion completa. Deteniendo..." "OK"
                    break
                }
            }
            $ultimoEstadoSync = $estadoOneDrive.Sincronizando
        }

        # Mantener sistema activo
        Set-ModoEnergia -Modo $Script:Config.ModoEnergia

        # Mostrar estado
        $tiempoTranscurrido = Get-TiempoTranscurrido
        $tiempoRestante = Get-TiempoRestante

        Write-Host "`r  ⏱️  Tiempo: $tiempoTranscurrido | Restante: $tiempoRestante | OneDrive: $($estadoOneDrive.Estado) | Velocidad: $($velocidad.Velocidad)     " -NoNewline -ForegroundColor White

        # Log periodico
        Write-Log "Estado: OneDrive=$($estadoOneDrive.Estado), Archivos=$($velocidad.TotalArchivos), Velocidad=$($velocidad.Velocidad)" "SYNC"

        # Esperar intervalo
        Start-Sleep -Seconds $Script:Config.IntervaloSegundos
    }

    # Limpiar
    Reset-ModoEnergia
    Write-Log "=== Sesion finalizada ===" "INFO"

    Write-Host ""
    Write-Host ""
    Write-Host "  ✓ Reposo Pro finalizado correctamente" -ForegroundColor Green
    Write-Host ""
}

# ============================================================
# PUNTO DE ENTRADA
# ============================================================
try {
    # Cargar configuracion si se especifico
    if (-not [string]::IsNullOrEmpty($ConfigFile)) {
        Import-Configuracion -Path $ConfigFile
    }

    Show-Banner

    # Menu interactivo
    $continuar = $true
    while ($continuar) {
        Show-ConfiguracionActual
        Show-Menu

        $opcion = Read-Host "  Selecciona una opcion (1-7)"

        switch ($opcion) {
            "1" {
                $continuar = $false
                Start-MonitoreoActivo
            }
            "2" { Set-ConfiguracionTemporizador }
            "3" { Set-ConfiguracionNotificaciones }
            "4" { Set-ConfiguracionEnergia }
            "5" {
                $path = Read-Host "  Ruta del archivo de configuracion"
                if (Test-Path $path) {
                    Import-Configuracion -Path $path
                } else {
                    Write-Host "  Archivo no encontrado" -ForegroundColor Red
                }
            }
            "6" {
                $path = Read-Host "  Ruta para guardar (Enter = Reposo-Config.json)"
                if ([string]::IsNullOrEmpty($path)) {
                    $path = Join-Path $PSScriptRoot "Reposo-Config.json"
                }
                $Script:Config | ConvertTo-Json -Depth 3 | Set-Content -Path $path
                Write-Host "  Configuracion guardada en: $path" -ForegroundColor Green
            }
            "7" {
                $continuar = $false
                Write-Host "  Saliendo..." -ForegroundColor Yellow
            }
            default {
                Write-Host "  Opcion no valida" -ForegroundColor Red
            }
        }
    }
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Reset-ModoEnergia
}
finally {
    Reset-ModoEnergia
}
