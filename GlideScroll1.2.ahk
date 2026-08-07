#Requires AutoHotkey v2.0
#SingleInstance Force
#MaxThreadsPerHotkey 1
#UseHook
InstallMouseHook()

TraySetIcon("shell32.dll", 101)

; Ctrl+Shift+R = Reload script
; ^+r::Reload()

; --- High DPI & Timing Fixes ---
DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
DllCall("Winmm\timeBeginPeriod", "UInt", 1)

CoordMode "Mouse", "Screen"
SetWinDelay -1
SetControlDelay -1

; ============================================
; GlideScroll v1.2
; A smooth middle-mouse scrolling utility
;
; This project was built with AI assistance
; (Claude by Anthropic, Gemini 3 Pro by Google, GLM 4.7 by z.ai).
; Human provided direction, testing, and feedback.
;
; License: MIT
; https://github.com/vuggarL/GlideScroll
; ============================================

global VERSION := "1.2.1"

; --- Configuration ---
global CONFIG_FILE := A_ScriptDir "\GlideScroll.ini"

; --- Core Settings ---
global SCROLL_SENSITIVITY := 100
global DEADZONE := 0
global POLL_RATE := 8
global SMOOTHING := 0.3
global CLICK_THRESHOLD := 0.10
global MAX_SCROLL_SPEED := 500

; --- Feature Toggles ---
global ENABLE_HORIZONTAL := true
global ENABLE_AXIS_LOCK := true
global INVERT_SCROLL := false
global ENABLE_ACCELERATION := false
global SHOW_INDICATOR := false

; --- Acceleration Setting ---
global ACCELERATION_CURVE := 1.5

; --- Presets ---
global CURRENT_PRESET := "Fast"
global PRESETS := Map(
    "Fine", Map("sensitivity", 30, "maxSpeed", 80, "smoothing", 0.8, "deadzone", 3),
    "Normal", Map("sensitivity", 60, "maxSpeed", 150, "smoothing", 0.7, "deadzone", 2),
    "Fast", Map("sensitivity", 100, "maxSpeed", 500, "smoothing", 0.3, "deadzone", 0),
    "Turbo", Map("sensitivity", 160, "maxSpeed", 400, "smoothing", 0.3, "deadzone", 1)
)

; --- Runtime State ---
global isScrolling := false
global isEnabled := true
global g_pressTime := 0
global g_anchorX := 0
global g_anchorY := 0
global g_smoothX := 0.0
global g_smoothY := 0.0
global g_buttonReleased := false
global g_cursorHidden := false

; --- Debug ---
global DEBUG_MODE := false
global g_scrollStartTime := 0
global g_bugCount := 0
global g_scrollCount := 0

; --- Initialization ---
LoadSettings()
ScrollIndicator.Init()
SetupTrayMenu()
UpdateIconTip()
UpdateMenus()
SetupSafetyWatchdog()
DebugLog("=== GlideScroll Started ===")

; ============================================
; HELPER FUNCTIONS
; ============================================

Clamp(val, minVal, maxVal) => Min(Max(val, minVal), maxVal)
Sign(val) => val > 0 ? 1 : val < 0 ? -1 : 0

ShowNotification(text, duration := 2000) {
    ToolTip()
    ToolTip text
    SetTimer () => ToolTip(), -duration
}

; ============================================
; DEBUG FUNCTIONS
; ============================================

DebugLog(message) {
    global DEBUG_MODE
    if !DEBUG_MODE
        return

    timestamp := FormatTime(, "HH:mm:ss")
    try FileAppend timestamp " - " message "`n", A_ScriptDir "\GlideScroll_debug.log"
}

DebugAlert(message) {
    global DEBUG_MODE, g_bugCount
    if !DEBUG_MODE
        return

    g_bugCount++

    SoundBeep 1000, 200

    ToolTip "⚠️ BUG #" g_bugCount ": " message
    SetTimer () => ToolTip(), -3000

    DebugLog "BUG DETECTED: " message " (Total: " g_bugCount ")"
}

DebugStatus(*) {
    global g_bugCount, g_scrollCount
    MsgBox(
        "Debug Statistics`n`n"
        "Total scrolls: " g_scrollCount "`n"
        "Bugs detected: " g_bugCount "`n"
        "Bug rate: " (g_scrollCount > 0 ? Round(g_bugCount / g_scrollCount * 100, 2) : 0) "%",
        "GlideScroll Debug",
        "Iconi"
    )
}

; ============================================
; SAFETY SYSTEMS
; ============================================

SetupSafetyWatchdog() {
    OnExit ExitCleanup
    SetTimer WatchdogCheck, 5000
}

WatchdogCheck() {
    global isScrolling, g_cursorHidden
    if !isScrolling && !GetKeyState("MButton", "P") && g_cursorHidden {
        DebugLog("WatchdogCheck: Cursor stuck hidden, restoring")
        SystemCursor("On")
    }
}

; Emergency cursor restore
^!r:: {
    global isScrolling, g_buttonReleased
    Critical
    SystemCursor("On")
    ScrollIndicator.Hide()
    isScrolling := false
    g_buttonReleased := true
    SetTimer ScrollTick, 0
    SetTimer AltScrollTick, 0
    SetTimer CheckScrollStart, 0
    SetTimer SafetyTimer, 0
    Critical "Off"
    DebugLog("Emergency restore triggered")
    ShowNotification("Cursor Restored!")
}

; Global toggle
#MButton:: {
    global isEnabled, isScrolling
    if !isScrolling {
        isEnabled := !isEnabled
        TraySetIcon A_AhkPath, isEnabled ? 1 : 3
        ShowNotification("GlideScroll " (isEnabled ? "ON" : "OFF"))
        DebugLog("Toggle: " (isEnabled ? "ON" : "OFF"))
    }
}

; ============================================
; SETTINGS PERSISTENCE
; ============================================

LoadSettings() {
    global CONFIG_FILE
    global SCROLL_SENSITIVITY, DEADZONE, POLL_RATE, SMOOTHING
    global CLICK_THRESHOLD, MAX_SCROLL_SPEED, ACCELERATION_CURVE
    global ENABLE_HORIZONTAL, ENABLE_AXIS_LOCK, INVERT_SCROLL
    global ENABLE_ACCELERATION, SHOW_INDICATOR, DEBUG_MODE, CURRENT_PRESET

    try {
        val := IniRead(CONFIG_FILE, "Settings", "Sensitivity", 100)
        SCROLL_SENSITIVITY := IsNumber(val) ? Clamp(Integer(val), 1, 200) : 100

        val := IniRead(CONFIG_FILE, "Settings", "Deadzone", 0)
        DEADZONE := IsNumber(val) ? Clamp(Integer(val), 0, 20) : 0

        val := IniRead(CONFIG_FILE, "Settings", "PollRate", 8)
        POLL_RATE := IsNumber(val) ? Clamp(Integer(val), 1, 50) : 8

        val := IniRead(CONFIG_FILE, "Settings", "Smoothing", 0.3)
        SMOOTHING := IsNumber(val) ? Clamp(Float(val), 0.0, 1.0) : 0.3

        val := IniRead(CONFIG_FILE, "Settings", "ClickThreshold", 0.10)
        CLICK_THRESHOLD := IsNumber(val) ? Clamp(Float(val), 0.05, 2.0) : 0.10

        val := IniRead(CONFIG_FILE, "Settings", "MaxSpeed", 500)
        MAX_SCROLL_SPEED := IsNumber(val) ? Clamp(Integer(val), 20, 1000) : 500

        val := IniRead(CONFIG_FILE, "Settings", "AccelCurve", 1.5)
        ACCELERATION_CURVE := IsNumber(val) ? Float(val) : 1.5

        ENABLE_HORIZONTAL := IniRead(CONFIG_FILE, "Features", "Horizontal", 1) = "1"
        ENABLE_AXIS_LOCK := IniRead(CONFIG_FILE, "Features", "AxisLock", 1) = "1"
        INVERT_SCROLL := IniRead(CONFIG_FILE, "Features", "Invert", 0) = "1"
        ENABLE_ACCELERATION := IniRead(CONFIG_FILE, "Features", "Acceleration", 0) = "1"
        SHOW_INDICATOR := IniRead(CONFIG_FILE, "Features", "ShowIndicator", 0) = "1"
        DEBUG_MODE := IniRead(CONFIG_FILE, "Features", "DebugMode", 0) = "1"

        CURRENT_PRESET := IniRead(CONFIG_FILE, "General", "Preset", "Fast")
    } catch as e {
        DebugLog("Settings load failed: " e.Message)
    }
}

SaveSettings() {
    global CONFIG_FILE
    global SCROLL_SENSITIVITY, DEADZONE, POLL_RATE, SMOOTHING
    global CLICK_THRESHOLD, MAX_SCROLL_SPEED, ACCELERATION_CURVE
    global ENABLE_HORIZONTAL, ENABLE_AXIS_LOCK, INVERT_SCROLL
    global ENABLE_ACCELERATION, SHOW_INDICATOR, DEBUG_MODE, CURRENT_PRESET
    
    try {
        IniWrite SCROLL_SENSITIVITY, CONFIG_FILE, "Settings", "Sensitivity"
        IniWrite DEADZONE, CONFIG_FILE, "Settings", "Deadzone"
        IniWrite POLL_RATE, CONFIG_FILE, "Settings", "PollRate"
        IniWrite SMOOTHING, CONFIG_FILE, "Settings", "Smoothing"
        IniWrite CLICK_THRESHOLD, CONFIG_FILE, "Settings", "ClickThreshold"
        IniWrite MAX_SCROLL_SPEED, CONFIG_FILE, "Settings", "MaxSpeed"
        IniWrite ACCELERATION_CURVE, CONFIG_FILE, "Settings", "AccelCurve"

        IniWrite ENABLE_HORIZONTAL ? 1 : 0, CONFIG_FILE, "Features", "Horizontal"
        IniWrite ENABLE_AXIS_LOCK ? 1 : 0, CONFIG_FILE, "Features", "AxisLock"
        IniWrite INVERT_SCROLL ? 1 : 0, CONFIG_FILE, "Features", "Invert"
        IniWrite ENABLE_ACCELERATION ? 1 : 0, CONFIG_FILE, "Features", "Acceleration"
        IniWrite SHOW_INDICATOR ? 1 : 0, CONFIG_FILE, "Features", "ShowIndicator"
        IniWrite DEBUG_MODE ? 1 : 0, CONFIG_FILE, "Features", "DebugMode"

        IniWrite CURRENT_PRESET, CONFIG_FILE, "General", "Preset"
    } catch as e {
        DebugLog("Settings save failed: " e.Message)
    }
}

; ============================================
; TRAY MENU
; ============================================

SetupTrayMenu() {
    try A_TrayMenu.Delete()

    A_TrayMenu.Add("GlideScroll v" VERSION, (*) => ShowAbout())
    A_TrayMenu.Disable("GlideScroll v" VERSION)
    A_TrayMenu.Add()

    ; Presets submenu
    presetMenu := Menu()
    presetMenu.Add("Fine (Precise)", (*) => ApplyPreset("Fine"))
    presetMenu.Add("Normal (Default)", (*) => ApplyPreset("Normal"))
    presetMenu.Add("Fast (Quick)", (*) => ApplyPreset("Fast"))
    presetMenu.Add("Turbo (Speed)", (*) => ApplyPreset("Turbo"))
    A_TrayMenu.Add("Presets", presetMenu)

    ; Settings submenu
    settingsMenu := Menu()
    settingsMenu.Add("Sensitivity...", AdjustSensitivity)
    settingsMenu.Add("Deadzone...", AdjustDeadzone)
    settingsMenu.Add("Max Speed...", AdjustMaxSpeed)
    settingsMenu.Add("Click Threshold...", AdjustClickThreshold)
    A_TrayMenu.Add("Settings", settingsMenu)

    ; Features submenu
    featuresMenu := Menu()
    featuresMenu.Add("Horizontal Scroll", ToggleHorizontal)
    featuresMenu.Add("Axis Locking", ToggleAxisLock)
    featuresMenu.Add("Invert Scroll", ToggleInvert)
    featuresMenu.Add("Acceleration", ToggleAcceleration)
    featuresMenu.Add()
    featuresMenu.Add("Scroll Indicator", ToggleIndicator)
    A_TrayMenu.Add("Features", featuresMenu)

    A_TrayMenu.Add()
    A_TrayMenu.Add("Autostart with Windows", ToggleAutostart)
    A_TrayMenu.Add()

    ; Debug submenu
    debugMenu := Menu()
    debugMenu.Add("Enable Debug Logging", ToggleDebugMode)
    debugMenu.Add("Show Debug Stats", DebugStatus)
    debugMenu.Add("Open Debug Log", (*) => OpenDebugLog())
    debugMenu.Add("Clear Debug Log", (*) => ClearDebugLog())
    A_TrayMenu.Add("Debug", debugMenu)

    A_TrayMenu.Add()
    A_TrayMenu.Add("Pause", TogglePause)
    A_TrayMenu.Add("Reload", (*) => Reload())
    A_TrayMenu.Add("Exit", (*) => ExitApp())

    A_TrayMenu.Default := "Exit"
    A_TrayMenu.ClickCount := 1

    global g_FeaturesMenu := featuresMenu
    global g_PresetMenu := presetMenu
    global g_DebugMenu := debugMenu
}

OpenDebugLog() {
    logFile := A_ScriptDir "\GlideScroll_debug.log"
    if FileExist(logFile)
        Run logFile
    else
        ShowNotification("No debug log yet")
}

ClearDebugLog() {
    global g_bugCount, g_scrollCount
    logFile := A_ScriptDir "\GlideScroll_debug.log"
    try FileDelete logFile
    g_bugCount := 0
    g_scrollCount := 0
    DebugLog("=== Log Cleared ===")
    ShowNotification("Debug log cleared")
}

UpdateMenus() {
    global g_FeaturesMenu, g_DebugMenu
    global ENABLE_HORIZONTAL, ENABLE_AXIS_LOCK, INVERT_SCROLL
    global ENABLE_ACCELERATION, SHOW_INDICATOR, DEBUG_MODE

    try {
        CheckMenuItem(g_FeaturesMenu, "Horizontal Scroll", ENABLE_HORIZONTAL)
        CheckMenuItem(g_FeaturesMenu, "Axis Locking", ENABLE_AXIS_LOCK)
        CheckMenuItem(g_FeaturesMenu, "Invert Scroll", INVERT_SCROLL)
        CheckMenuItem(g_FeaturesMenu, "Acceleration", ENABLE_ACCELERATION)
        CheckMenuItem(g_FeaturesMenu, "Scroll Indicator", SHOW_INDICATOR)
        CheckMenuItem(g_DebugMenu, "Enable Debug Logging", DEBUG_MODE)
        UpdatePresetMenu()
        UpdateAutostartMenu()
    }
}

UpdatePresetMenu() {
    global g_PresetMenu, CURRENT_PRESET, PRESETS

    static menuNames := Map(
        "Fine", "Fine (Precise)",
        "Normal", "Normal (Default)",
        "Fast", "Fast (Quick)",
        "Turbo", "Turbo (Speed)"
    )

    for presetKey, _ in PRESETS {
        if menuNames.Has(presetKey) {
            menuText := menuNames[presetKey]
            try {
                if (presetKey = CURRENT_PRESET)
                    g_PresetMenu.Check(menuText)
                else
                    g_PresetMenu.Uncheck(menuText)
            }
        }
    }
}

UpdateIconTip() {
    global isEnabled, VERSION, CURRENT_PRESET, SCROLL_SENSITIVITY, MAX_SCROLL_SPEED

    status := isEnabled ? "" : " (DISABLED)"   ; now correctly a local
    A_IconTip := "GlideScroll v" VERSION status "`n"
            . "Preset: " CURRENT_PRESET "`n"
            . "Sensitivity: " SCROLL_SENSITIVITY "`n"
            . "Max Speed: " MAX_SCROLL_SPEED "`n"
            . "Win+MButton: Toggle | Ctrl+Alt+R: Restore"
}

CheckMenuItem(menu, name, isChecked) {
    try {
        if isChecked
            menu.Check(name)
        else
            menu.Uncheck(name)
    }
}

ShowAbout(*) {
    MsgBox(
        "GlideScroll v" VERSION "`n`n"
        "A smooth scrolling utility for Windows.`n`n"
        "Hotkeys:`n"
        "  Middle Mouse (hold) - Glide mode`n"
        "  Middle Mouse (click) - Normal click`n"
        "  Right Alt+Left Click (hold) - Glide mode (backup)`n"
        "  Right Alt+Left Click (tap) - Middle click (backup)`n"
        "  Win + Middle Mouse - Toggle on/off`n"
        "  Ctrl + Alt + R - Restore cursor`n`n"
        "Made with AutoHotkey v2",
        "About GlideScroll",
        "Iconi"
    )
}

; ============================================
; TOGGLE FUNCTIONS
; ============================================

ToggleHorizontal(*) {
    global ENABLE_HORIZONTAL := !ENABLE_HORIZONTAL
    SaveSettings()
    UpdateMenus()
    ShowNotification("Horizontal Scroll " (ENABLE_HORIZONTAL ? "ON" : "OFF"))
}

ToggleAxisLock(*) {
    global ENABLE_AXIS_LOCK := !ENABLE_AXIS_LOCK
    SaveSettings()
    UpdateMenus()
    ShowNotification("Axis Locking " (ENABLE_AXIS_LOCK ? "ON" : "OFF"))
}

ToggleInvert(*) {
    global INVERT_SCROLL := !INVERT_SCROLL
    SaveSettings()
    UpdateMenus()
    ShowNotification("Invert Scroll " (INVERT_SCROLL ? "ON" : "OFF"))
}

ToggleAcceleration(*) {
    global ENABLE_ACCELERATION := !ENABLE_ACCELERATION
    SaveSettings()
    UpdateMenus()
    ShowNotification("Acceleration " (ENABLE_ACCELERATION ? "ON" : "OFF"))
}

ToggleIndicator(*) {
    global SHOW_INDICATOR := !SHOW_INDICATOR
    SaveSettings()
    UpdateMenus()
    ShowNotification("Scroll Indicator " (SHOW_INDICATOR ? "ON" : "OFF"))
}

ToggleDebugMode(*) {
    global DEBUG_MODE := !DEBUG_MODE
    SaveSettings()
    UpdateMenus()
    if DEBUG_MODE
        DebugLog("=== Debug Mode Enabled ===")
    ShowNotification("Debug Logging " (DEBUG_MODE ? "ON" : "OFF"))
}

; ============================================
; PRESET FUNCTIONS
; ============================================

ApplyPreset(presetName) {
    global CURRENT_PRESET, PRESETS
    global SCROLL_SENSITIVITY, MAX_SCROLL_SPEED, SMOOTHING, DEADZONE

    if !PRESETS.Has(presetName)
        return

    preset := PRESETS[presetName]
    SCROLL_SENSITIVITY := preset["sensitivity"]
    MAX_SCROLL_SPEED := preset["maxSpeed"]
    SMOOTHING := preset["smoothing"]
    DEADZONE := preset["deadzone"]
    CURRENT_PRESET := presetName

    SaveSettings()
    UpdateIconTip()
    UpdateMenus()
    ShowNotification("Preset: " presetName)
}

; ============================================
; ADJUSTMENT FUNCTIONS
; ============================================

AdjustSensitivity(*) {
    global SCROLL_SENSITIVITY
    IB := InputBox("Enter sensitivity (1-200)`nCurrent: " SCROLL_SENSITIVITY, "Sensitivity", "w280 h120")
    if (IB.Result = "OK") && IsNumber(IB.Value) {
        val := Integer(IB.Value)
        if (val >= 1 && val <= 200) {
            SCROLL_SENSITIVITY := val
            SaveSettings()
            UpdateIconTip()
            ShowNotification("Sensitivity: " SCROLL_SENSITIVITY)
        } else {
            ShowNotification("Invalid! Must be 1-200")
        }
    }
}

AdjustDeadzone(*) {
    global DEADZONE
    IB := InputBox("Enter deadzone (0-20)`nCurrent: " DEADZONE, "Deadzone", "w280 h120")
    if (IB.Result = "OK") && IsNumber(IB.Value) {
        val := Integer(IB.Value)
        if (val >= 0 && val <= 20) {
            DEADZONE := val
            SaveSettings()
            UpdateIconTip()
            ShowNotification("Deadzone: " DEADZONE)
        } else {
            ShowNotification("Invalid! Must be 0-20")
        }
    }
}

AdjustMaxSpeed(*) {
    global MAX_SCROLL_SPEED
    IB := InputBox("Enter max speed (20-1000)`nCurrent: " MAX_SCROLL_SPEED, "Max Speed", "w280 h120")
    if (IB.Result = "OK") && IsNumber(IB.Value) {
        val := Integer(IB.Value)
        if (val >= 20 && val <= 1000) {
            MAX_SCROLL_SPEED := val
            SaveSettings()
            UpdateIconTip()
            ShowNotification("Max Speed: " MAX_SCROLL_SPEED)
        } else {
            ShowNotification("Invalid! Must be 20-1000")
        }
    }
}

AdjustClickThreshold(*) {
    global CLICK_THRESHOLD
    current := Round(CLICK_THRESHOLD, 2)
    IB := InputBox("Enter click threshold in seconds (0.05-2.0)`nCurrent: " current, "Click Threshold", "w280 h120")
    if (IB.Result = "OK") && IsNumber(IB.Value) {
        val := Float(IB.Value)
        if (val >= 0.05 && val <= 2.0) {
            CLICK_THRESHOLD := Round(val, 2)
            SaveSettings()
            ShowNotification("Click Threshold: " CLICK_THRESHOLD "s")
        } else {
            ShowNotification("Invalid! Must be 0.05-2.0")
        }
    }
}

; ============================================
; AUTOSTART
; ============================================

ToggleAutostart(*) {
    static AppName := "GlideScroll"
    static RegPath := "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run"

    try {
        RegRead(RegPath, AppName)
        RegDelete RegPath, AppName
        ShowNotification("Autostart OFF")
    } catch {
        RegWrite '"' A_ScriptFullPath '"', "REG_SZ", RegPath, AppName
        ShowNotification("Autostart ON")
    }
    UpdateAutostartMenu()
}

UpdateAutostartMenu() {
    static AppName := "GlideScroll"
    static RegPath := "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run"

    isOn := false
    try {
        RegRead(RegPath, AppName)
        isOn := true
    }

    try {
        if isOn
            A_TrayMenu.Check("Autostart with Windows")
        else
            A_TrayMenu.Uncheck("Autostart with Windows")
    }
}

TogglePause(*) {
    Pause(-1)
    if A_IsPaused {
        try A_TrayMenu.Rename("Pause", "Resume")
        A_IconTip := "GlideScroll v" VERSION " (PAUSED)"
        ShowNotification("Paused")
    } else {
        try A_TrayMenu.Rename("Resume", "Pause")
        UpdateIconTip()
        ShowNotification("Resumed")
    }
}

; ============================================
; SCROLL INDICATOR
; ============================================

class ScrollIndicator {
    static gui := 0
    static isShowing := false

    static Init() {
        this.gui := 0
        this.isShowing := false
        this.EnsureGui()
    }

    static EnsureGui() {
        if this.gui
            return
        this.gui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
        this.gui.BackColor := "FF6600"
        this.gui.Show("w8 h8 Hide")
        WinSetTransparent(200, this.gui)
        WinSetRegion("0-0 W8 H8 E", this.gui)
    }

    static Show(x, y) {
        this.EnsureGui()
        if this.gui {
            this.gui.Show("x" (x - 4) " y" (y - 4) " w8 h8 NoActivate")
            this.isShowing := true
        }
    }

    static Hide() {
        if this.gui && this.isShowing {
            this.gui.Hide()
            this.isShowing := false
        }
    }
}

; ============================================
; SHARED SCROLL MATH
; ============================================

DoScrollMath() {
    global g_anchorX, g_anchorY, g_smoothX, g_smoothY
    global SCROLL_SENSITIVITY, MAX_SCROLL_SPEED, SMOOTHING, DEADZONE
    global ENABLE_HORIZONTAL, INVERT_SCROLL, ENABLE_ACCELERATION, ENABLE_AXIS_LOCK
    global ACCELERATION_CURVE

    MouseGetPos(&curr_x, &curr_y)

    raw_delta_y := (curr_y - g_anchorY) * SCROLL_SENSITIVITY / 10
    raw_delta_x := (curr_x - g_anchorX) * SCROLL_SENSITIVITY / 10

    if INVERT_SCROLL {
        raw_delta_y := -raw_delta_y
        raw_delta_x := -raw_delta_x
    }

    g_smoothY := g_smoothY * SMOOTHING + raw_delta_y * (1 - SMOOTHING)
    g_smoothX := g_smoothX * SMOOTHING + raw_delta_x * (1 - SMOOTHING)

    ; Clamp state BEFORE copying so acceleration sees bounded values
    g_smoothY := Clamp(g_smoothY, -MAX_SCROLL_SPEED * 2, MAX_SCROLL_SPEED * 2)
    g_smoothX := Clamp(g_smoothX, -MAX_SCROLL_SPEED * 2, MAX_SCROLL_SPEED * 2)

    smoothY := g_smoothY
    smoothX := g_smoothX

    if ENABLE_ACCELERATION {
        smoothY := Sign(smoothY) * (Abs(smoothY) ** ACCELERATION_CURVE) / 50
        smoothX := Sign(smoothX) * (Abs(smoothX) ** ACCELERATION_CURVE) / 50
    }

    smoothY := Clamp(smoothY, -MAX_SCROLL_SPEED, MAX_SCROLL_SPEED)
    smoothX := Clamp(smoothX, -MAX_SCROLL_SPEED, MAX_SCROLL_SPEED)

    if ENABLE_AXIS_LOCK {
        if Abs(smoothY) > Abs(smoothX) * 1.5
            smoothX := 0
        else if Abs(smoothX) > Abs(smoothY) * 1.5
            smoothY := 0
    }

    if Abs(smoothY) > DEADZONE
        DllCall("mouse_event", "UInt", 0x0800, "Int", 0, "Int", 0, "Int", -Integer(smoothY), "UInt", 0)

    if ENABLE_HORIZONTAL && Abs(smoothX) > DEADZONE
        DllCall("mouse_event", "UInt", 0x1000, "Int", 0, "Int", 0, "Int", Integer(smoothX), "UInt", 0)

    if (curr_x != g_anchorX || curr_y != g_anchorY)
        MouseMove(g_anchorX, g_anchorY, 0)
}

; ============================================
; MAIN SCROLL LOGIC — MIDDLE MOUSE BUTTON
; ============================================

MButton:: {
    global isScrolling, isEnabled, CLICK_THRESHOLD
    global g_pressTime, g_anchorX, g_anchorY, g_smoothX, g_smoothY
    global g_buttonReleased

    Critical

    if isScrolling {
        DebugLog("MButton DOWN while already scrolling - missed release detected!")
        DebugAlert("Missed MButton release")
        ; Clean stop without touching Critical state — we own it here
        isScrolling := false
        SetTimer ScrollTick, 0
        SetTimer SafetyTimer, 0
        SetTimer CheckScrollStart, 0
        ScrollIndicator.Hide()
        SystemCursor("On")
    }

    if !isEnabled {
        Critical "Off"
        SendEvent "{MButton Down}"
        return
    }

    g_buttonReleased := false
    g_pressTime := A_TickCount
    MouseGetPos(&g_anchorX, &g_anchorY)
    g_smoothX := 0.0
    g_smoothY := 0.0

    DebugLog("MButton DOWN at " g_anchorX "," g_anchorY)

    Critical "Off"
    SetTimer CheckScrollStart, -1
}

CheckScrollStart() {
    global isScrolling, isEnabled, CLICK_THRESHOLD, SHOW_INDICATOR, POLL_RATE
    global g_pressTime, g_anchorX, g_anchorY, g_buttonReleased
    global g_scrollStartTime, g_scrollCount

    threshold_ms := Integer(CLICK_THRESHOLD * 1000)

    while (A_TickCount - g_pressTime) < threshold_ms {
        if g_buttonReleased || !GetKeyState("MButton", "P") {
            DebugLog("Released during threshold wait")
            return
        }
        Sleep 2
    }

    ; Enter Critical to atomically check and set scrolling state
    Critical

    ; Re-check after acquiring Critical — release could have happened
    if g_buttonReleased || !GetKeyState("MButton", "P") {
        DebugLog("Released right after threshold (inside Critical)")
        Critical "Off"
        return
    }

    isScrolling := true
    g_scrollStartTime := A_TickCount
    g_scrollCount++

    DebugLog("SCROLL START #" g_scrollCount)

    Critical "Off"

    SystemCursor("Off")

    if SHOW_INDICATOR
        ScrollIndicator.Show(g_anchorX, g_anchorY)

    SetTimer ScrollTick, POLL_RATE
    SetTimer SafetyTimer, 30
}

ScrollTick() {
    global isScrolling, g_buttonReleased
    static releaseCount := 0

    if !isScrolling {
        releaseCount := 0
        return
    }

    if g_buttonReleased {
        DebugLog("ScrollTick: g_buttonReleased flag set")
        StopScrollingFromTimer()
        releaseCount := 0
        return
    }

    if !GetKeyState("MButton", "P") {
        releaseCount++
        if releaseCount >= 3 {
            DebugLog("ScrollTick: Confirmed release after " releaseCount " ticks")
            StopScrollingFromTimer()
            releaseCount := 0
        }
        return
    }
    releaseCount := 0

    DoScrollMath()
}

MButton Up:: {
    global isScrolling, isEnabled, CLICK_THRESHOLD, g_pressTime, g_buttonReleased

    Critical

    g_buttonReleased := true

    DebugLog("MButton UP (isScrolling=" isScrolling ")")

    SetTimer CheckScrollStart, 0
    SetTimer ScrollTick, 0
    SetTimer SafetyTimer, 0

    if !isEnabled {
        Critical "Off"
        SendEvent "{MButton Up}"
        return
    }

    wasScrolling := isScrolling

    if wasScrolling {
        ; Inline stop — we own Critical here
        isScrolling := false
        ScrollIndicator.Hide()
        SystemCursor("On")
        DebugLog("SCROLL STOP from MButton Up (duration: " (A_TickCount - g_scrollStartTime) "ms)")
        Critical "Off"
    } else {
        Critical "Off"
        if (A_TickCount - g_pressTime) < (CLICK_THRESHOLD * 1000) {
            DebugLog("Sending click")
            SendEvent "{MButton}"
        }
    }
}

; ============================================
; BACKUP SCROLL TRIGGER — Right Alt + Left Click
; ============================================

>!LButton:: {
    global isEnabled, isScrolling, g_pressTime, g_anchorX, g_anchorY
    global g_smoothX, g_smoothY, g_buttonReleased
    global CLICK_THRESHOLD, SHOW_INDICATOR, POLL_RATE
    global g_scrollStartTime, g_scrollCount

    if !isEnabled || isScrolling
        return

    g_buttonReleased := false
    g_pressTime := A_TickCount
    MouseGetPos(&g_anchorX, &g_anchorY)
    g_smoothX := 0.0
    g_smoothY := 0.0

    threshold_ms := Integer(CLICK_THRESHOLD * 1000)
    while (A_TickCount - g_pressTime) < threshold_ms {
        if !GetKeyState("LButton", "P") {
            SendEvent "{MButton}"
            return
        }
        Sleep 2
    }

    if !GetKeyState("LButton", "P")
        return

    Critical
    isScrolling := true
    g_scrollStartTime := A_TickCount
    g_scrollCount++
    DebugLog("SCROLL START (Alt+LButton) #" g_scrollCount)
    Critical "Off"

    SystemCursor("Off")
    if SHOW_INDICATOR
        ScrollIndicator.Show(g_anchorX, g_anchorY)

    SetTimer AltScrollTick, POLL_RATE

    KeyWait "LButton"

    SetTimer AltScrollTick, 0

    Critical
    isScrolling := false
    ScrollIndicator.Hide()
    SystemCursor("On")
    DebugLog("SCROLL STOP (Alt+LButton, duration: " (A_TickCount - g_scrollStartTime) "ms)")
    Critical "Off"
}

AltScrollTick() {
    global isScrolling

    if !isScrolling
        return

    DoScrollMath()
}

; ============================================
; UNIFIED SAFETY TIMER
; ============================================

SafetyTimer() {
    global isScrolling, g_buttonReleased, g_scrollStartTime
    static failCount := 0

    if !isScrolling {
        SetTimer SafetyTimer, 0
        failCount := 0
        return
    }

    if g_buttonReleased {
        DebugLog("SafetyTimer: g_buttonReleased flag set")
        StopScrollingFromTimer()
        failCount := 0
        return
    }

    buttonHeld := GetKeyState("MButton", "P")

    if !buttonHeld {
        failCount++
        DebugLog("SafetyTimer: Button not held, failCount=" failCount)
        if failCount >= 3 {
            DebugLog("SafetyTimer: Confirmed release after " failCount " checks")
            DebugAlert("SafetyTimer caught missed release")
            StopScrollingFromTimer()
            failCount := 0
        }
    } else {
        failCount := 0
    }

    if (A_TickCount - g_scrollStartTime) > 30000 {
        DebugLog("Warning: Scrolling for over 30 seconds")
    }
}

; Called from timer context — safe to manage own Critical
StopScrollingFromTimer() {
    global isScrolling, g_scrollStartTime, g_cursorHidden, g_smoothX, g_smoothY

    Critical

    if !isScrolling {
        if g_cursorHidden
            SystemCursor("On")
        Critical "Off"
        return
    }

    duration := A_TickCount - g_scrollStartTime
    DebugLog("SCROLL STOP from timer (duration: " duration "ms)")

    isScrolling := false

    g_smoothX := 0.0
    g_smoothY := 0.0

    SetTimer ScrollTick, 0
    SetTimer AltScrollTick, 0
    SetTimer SafetyTimer, 0
    ScrollIndicator.Hide()
    SystemCursor("On")

    Critical "Off"
}

; ============================================
; EXIT CLEANUP
; ============================================

ExitCleanup(ExitReason, ExitCode) {
    Critical

    SetTimer WatchdogCheck, 0
    SetTimer ScrollTick, 0
    SetTimer AltScrollTick, 0
    SetTimer CheckScrollStart, 0
    SetTimer SafetyTimer, 0

    SystemCursor("On")
    ScrollIndicator.Hide()

    DebugLog("=== Script Exit: " ExitReason " ===")

    DllCall("Winmm\timeEndPeriod", "UInt", 1)

    SystemCursor("Cleanup")
}

; ============================================
; SYSTEM CURSOR CONTROL
; ============================================

SystemCursor(State) {
    static SystemCursors := [32512, 32513, 32514, 32515, 32516, 32642, 32643, 32644, 32645, 32646, 32648, 32649, 32650, 32651]
    static OldCursors := Map()
    static BlankCursor := 0

    global g_cursorHidden

    if State = "Off" {
        if g_cursorHidden || OldCursors.Count > 0
            return

        if !BlankCursor {
            andMask := Buffer(128, 0xFF)
            xorMask := Buffer(128, 0x00)
            BlankCursor := DllCall("CreateCursor", "Ptr", 0, "Int", 0, "Int", 0,
                                    "Int", 32, "Int", 32, "Ptr", andMask, "Ptr", xorMask, "Ptr")
        }

        for cursorType in SystemCursors {
            try {
                hOriginal := DllCall("LoadCursor", "Ptr", 0, "Int", cursorType, "Ptr")
                hBackup := DllCall("CopyImage", "Ptr", hOriginal, "UInt", 2, "Int", 0, "Int", 0, "UInt", 0, "Ptr")
                if hBackup
                    OldCursors[cursorType] := hBackup
                hBlankCopy := DllCall("CopyImage", "Ptr", BlankCursor, "UInt", 2, "Int", 0, "Int", 0, "UInt", 0, "Ptr")
                DllCall("SetSystemCursor", "Ptr", hBlankCopy, "Int", cursorType)
            } catch as e {
                DebugLog("SystemCursor Off error for " cursorType ": " e.Message)
            }
        }

        g_cursorHidden := true

    } else if State = "On" {
        if !g_cursorHidden && OldCursors.Count = 0
            return

        if OldCursors.Count > 0 {
            for cursorType, hBackup in OldCursors {
                try DllCall("SetSystemCursor", "Ptr", hBackup, "Int", cursorType)
                catch as e
                    DebugLog("SystemCursor On error for " cursorType ": " e.Message)
            }
            OldCursors := Map()
        } else {
            DllCall("SystemParametersInfo", "UInt", 0x0057, "UInt", 0, "Ptr", 0, "UInt", 0)
        }

        g_cursorHidden := false

    } else if State = "Cleanup" {
        if BlankCursor {
            DllCall("DestroyCursor", "Ptr", BlankCursor)
            BlankCursor := 0
        }
        if g_cursorHidden {
            DllCall("SystemParametersInfo", "UInt", 0x0057, "UInt", 0, "Ptr", 0, "UInt", 0)
            g_cursorHidden := false
        }
    }
}