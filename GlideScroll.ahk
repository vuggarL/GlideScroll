#Requires AutoHotkey v2.0
#SingleInstance Force
#MaxThreadsPerHotkey 1
#UseHook
InstallMouseHook()

; --- High DPI & Timing Fixes ---
DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr") ; Fixes mouse drift on high-res screens
DllCall("Winmm\timeBeginPeriod", "UInt", 1) ; Forces Windows to check for input faster (1ms precision)

CoordMode "Mouse", "Screen"
SetWinDelay -1
SetControlDelay -1

; ============================================
; GlideScroll v1.0
; A smooth middle-mouse scrolling utility
; 
; This project was built with AI assistance
; (Claude by Anthropic, Gemini 3 Pro by Google, GLM 4.7 by z.ai).
; Human provided direction, testing, and feedback.
;
; License: MIT
; https://github.com/vuggarL/GlideScroll
; ============================================

global VERSION := "1.0.0"

; --- Configuration ---
global CONFIG_FILE := A_ScriptDir "\GlideScroll.ini"

; --- Core Settings ---
global SCROLL_SENSITIVITY := 60
global DEADZONE := 2
global POLL_RATE := 8
global SMOOTHING := 0.7
global CLICK_THRESHOLD := 0.25
global MAX_SCROLL_SPEED := 150

; --- Feature Toggles ---
global ENABLE_HORIZONTAL := true
global ENABLE_AXIS_LOCK := true
global INVERT_SCROLL := false
global ENABLE_ACCELERATION := false
global SHOW_INDICATOR := true

; --- Acceleration Setting ---
global ACCELERATION_CURVE := 1.5

; --- Presets ---
global CURRENT_PRESET := "Normal"
global PRESETS := Map(
    "Fine", Map("sensitivity", 30, "maxSpeed", 80, "smoothing", 0.8, "deadzone", 3),
    "Normal", Map("sensitivity", 60, "maxSpeed", 150, "smoothing", 0.7, "deadzone", 2),
    "Fast", Map("sensitivity", 100, "maxSpeed", 250, "smoothing", 0.5, "deadzone", 1),
    "Turbo", Map("sensitivity", 160, "maxSpeed", 400, "smoothing", 0.3, "deadzone", 1)
)

; --- Runtime State ---
global isScrolling := false
global isEnabled := true

; --- Initialization ---
LoadSettings()
ScrollIndicator.Init()
SetupTrayMenu()
UpdateIconTip()
UpdateMenus()
SetupSafetyWatchdog()

; ============================================
; HELPER FUNCTIONS
; ============================================

Clamp(val, minVal, maxVal) => Min(Max(val, minVal), maxVal)
Sign(val) => val > 0 ? 1 : val < 0 ? -1 : 0

ShowNotification(text, duration := 2000) {
    ToolTip text
    SetTimer () => ToolTip(), -duration
}

; ============================================
; SAFETY SYSTEMS
; ============================================

SetupSafetyWatchdog() {
    OnExit ExitCleanup
    SetTimer WatchdogCheck, 5000
}

WatchdogCheck() {
    global isScrolling
    if !isScrolling && !GetKeyState("MButton", "P")
        SystemCursor("On")
}

; Emergency cursor restore
^!r:: {
    SystemCursor("On")
    ScrollIndicator.Hide()
    global isScrolling := false
    ShowNotification("Cursor Restored!")
}

; Global toggle
#MButton:: {
    global isEnabled, isScrolling
    if !isScrolling {
        isEnabled := !isEnabled
        TraySetIcon A_AhkPath, isEnabled ? 1 : 3
        ShowNotification("GlideScroll " (isEnabled ? "ON" : "OFF"))
    }
}

; ============================================
; SETTINGS PERSISTENCE
; ============================================

LoadSettings() {
    global
    try {
        SCROLL_SENSITIVITY := Integer(IniRead(CONFIG_FILE, "Settings", "Sensitivity", 60))
        DEADZONE := Integer(IniRead(CONFIG_FILE, "Settings", "Deadzone", 2))
        POLL_RATE := Integer(IniRead(CONFIG_FILE, "Settings", "PollRate", 8))
        SMOOTHING := Float(IniRead(CONFIG_FILE, "Settings", "Smoothing", 0.7))
        CLICK_THRESHOLD := Float(IniRead(CONFIG_FILE, "Settings", "ClickThreshold", 0.25))
        MAX_SCROLL_SPEED := Integer(IniRead(CONFIG_FILE, "Settings", "MaxSpeed", 150))
        ACCELERATION_CURVE := Float(IniRead(CONFIG_FILE, "Settings", "AccelCurve", 1.5))
        
        ENABLE_HORIZONTAL := IniRead(CONFIG_FILE, "Features", "Horizontal", 1) = "1"
        ENABLE_AXIS_LOCK := IniRead(CONFIG_FILE, "Features", "AxisLock", 1) = "1"
        INVERT_SCROLL := IniRead(CONFIG_FILE, "Features", "Invert", 0) = "1"
        ENABLE_ACCELERATION := IniRead(CONFIG_FILE, "Features", "Acceleration", 0) = "1"
        SHOW_INDICATOR := IniRead(CONFIG_FILE, "Features", "ShowIndicator", 1) = "1"
        
        CURRENT_PRESET := IniRead(CONFIG_FILE, "General", "Preset", "Normal")
    }
}

SaveSettings() {
    global
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
        
        IniWrite CURRENT_PRESET, CONFIG_FILE, "General", "Preset"
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
    A_TrayMenu.Add("Pause", TogglePause)
    A_TrayMenu.Add("Reload", (*) => Reload())
    A_TrayMenu.Add("Exit", (*) => ExitApp())
    
    A_TrayMenu.Default := "Exit"
    A_TrayMenu.ClickCount := 1
    
    global g_FeaturesMenu := featuresMenu
    global g_PresetMenu := presetMenu
}

UpdateMenus() {
    global g_FeaturesMenu
    
    try {
        CheckMenuItem(g_FeaturesMenu, "Horizontal Scroll", ENABLE_HORIZONTAL)
        CheckMenuItem(g_FeaturesMenu, "Axis Locking", ENABLE_AXIS_LOCK)
        CheckMenuItem(g_FeaturesMenu, "Invert Scroll", INVERT_SCROLL)
        CheckMenuItem(g_FeaturesMenu, "Acceleration", ENABLE_ACCELERATION)
        CheckMenuItem(g_FeaturesMenu, "Scroll Indicator", SHOW_INDICATOR)
        UpdateAutostartMenu()
    }
}

UpdateIconTip() {
    global
    status := isEnabled ? "" : " (DISABLED)"
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
    IB := InputBox("Enter max speed (20-500)`nCurrent: " MAX_SCROLL_SPEED, "Max Speed", "w280 h120")
    if (IB.Result = "OK") && IsNumber(IB.Value) {
        val := Integer(IB.Value)
        if (val >= 20 && val <= 500) {
            MAX_SCROLL_SPEED := val
            SaveSettings()
            UpdateIconTip()
            ShowNotification("Max Speed: " MAX_SCROLL_SPEED)
        } else {
            ShowNotification("Invalid! Must be 20-500")
        }
    }
}

AdjustClickThreshold(*) {
    global CLICK_THRESHOLD
    current := Round(CLICK_THRESHOLD, 2)
    IB := InputBox("Enter click threshold in seconds (0.1-1.0)`nCurrent: " current, "Click Threshold", "w280 h120")
    if (IB.Result = "OK") && IsNumber(IB.Value) {
        val := Float(IB.Value)
        if (val >= 0.1 && val <= 1.0) {
            CLICK_THRESHOLD := Round(val, 2)
            SaveSettings()
            ShowNotification("Click Threshold: " CLICK_THRESHOLD "s")
        } else {
            ShowNotification("Invalid! Must be 0.1-1.0")
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
        ; Create once at startup
        this.gui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
        this.gui.BackColor := "FF6600"
        this.gui.Show("w8 h8 Hide")
        WinSetTransparent(200, this.gui)
        WinSetRegion("0-0 W8 H8 E", this.gui)
    }
    
    static Show(x, y) {
        if this.gui {
            ; Only reposition - no creation
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
; MAIN SCROLL LOGIC
; ============================================

MButton:: {
    global isScrolling, isEnabled, CLICK_THRESHOLD
    global SCROLL_SENSITIVITY, MAX_SCROLL_SPEED, SMOOTHING, DEADZONE
    global ENABLE_HORIZONTAL, INVERT_SCROLL, ENABLE_ACCELERATION, ENABLE_AXIS_LOCK
    global SHOW_INDICATOR, ACCELERATION_CURVE
    
    ; Check if disabled
    if !isEnabled {
        SendEvent "{MButton Down}"
        KeyWait "MButton"
        SendEvent "{MButton Up}"
        return
    }
    
    ; Click vs hold detection
    if KeyWait("MButton", "T" CLICK_THRESHOLD) {
        SendEvent "{MButton}"
        return
    }
    
    ; Initialize scroll mode
    MouseGetPos(&anchor_x, &anchor_y)
    isScrolling := true
    SystemCursor("Off")
    
    if SHOW_INDICATOR
        ScrollIndicator.Show(anchor_x, anchor_y)
    
    smoothY := 0.0
    smoothX := 0.0
    
    ; Main scroll loop
Loop {
    if !GetKeyState("MButton", "P")
        break
    
    MouseGetPos(&curr_x, &curr_y)
    
    ; Calculate raw deltas
    raw_delta_y := (curr_y - anchor_y) * SCROLL_SENSITIVITY / 10
    raw_delta_x := (curr_x - anchor_x) * SCROLL_SENSITIVITY / 10
    
    ; Apply inversion
    if INVERT_SCROLL {
        raw_delta_y := -raw_delta_y
        raw_delta_x := -raw_delta_x
    }
    
    ; Apply smoothing (EMA)
    smoothY := smoothY * SMOOTHING + raw_delta_y * (1 - SMOOTHING)
    smoothX := smoothX * SMOOTHING + raw_delta_x * (1 - SMOOTHING)
    
    ; Apply acceleration
    if ENABLE_ACCELERATION {
        smoothY := Sign(smoothY) * (Abs(smoothY) ** ACCELERATION_CURVE) / 50 * SCROLL_SENSITIVITY
        smoothX := Sign(smoothX) * (Abs(smoothX) ** ACCELERATION_CURVE) / 50 * SCROLL_SENSITIVITY
    }
    
    ; Apply max speed cap
    smoothY := Clamp(smoothY, -MAX_SCROLL_SPEED, MAX_SCROLL_SPEED)
    smoothX := Clamp(smoothX, -MAX_SCROLL_SPEED, MAX_SCROLL_SPEED)
    
    ; Apply axis locking
    if ENABLE_AXIS_LOCK {
        if Abs(smoothY) > Abs(smoothX) * 2.5
            smoothX := 0
        else if Abs(smoothX) > Abs(smoothY) * 2.5
            smoothY := 0
    }
    
    ; Send scroll events
    ; Vertical: negative = scroll down
    if Abs(smoothY) > DEADZONE
        DllCall("mouse_event", "UInt", 0x0800, "Int", 0, "Int", 0, "Int", -Integer(smoothY), "UInt", 0)
    
    ; Horizontal: positive = scroll right
    if ENABLE_HORIZONTAL && Abs(smoothX) > DEADZONE
        DllCall("mouse_event", "UInt", 0x1000, "Int", 0, "Int", 0, "Int", Integer(smoothX), "UInt", 0)
    
    ; Reset mouse position
    MouseMove(anchor_x, anchor_y, 0)
    
    Sleep POLL_RATE
}
    
    ; Cleanup
    ScrollIndicator.Hide()
    SystemCursor("On")
    isScrolling := false
}

; ============================================
; EXIT CLEANUP
; ============================================

ExitCleanup(ExitReason, ExitCode) {
    Critical
    SystemCursor("On")
    ScrollIndicator.Hide()
    SetTimer WatchdogCheck, 0
    
    ; Reset high precision timer
    DllCall("Winmm\timeEndPeriod", "UInt", 1)
    
    if ExitReason = "Reload"
        return
    
    SystemCursor("Cleanup")
}

; ============================================
; SYSTEM CURSOR CONTROL
; ============================================

SystemCursor(State) {
    static SystemCursors := [32512, 32513, 32514, 32515, 32516, 32642, 32643, 32644, 32645, 32646, 32648, 32649, 32650, 32651]
    static OldCursors := Map()
    static BlankCursor := 0
    
    if State = "Off" {
        if OldCursors.Count > 0
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
                OldCursors[cursorType] := hBackup
                hBlankCopy := DllCall("CopyImage", "Ptr", BlankCursor, "UInt", 2, "Int", 0, "Int", 0, "UInt", 0, "Ptr")
                DllCall("SetSystemCursor", "Ptr", hBlankCopy, "Int", cursorType)
            }
        }
    } else if State = "On" {
        for cursorType, hBackup in OldCursors {
            try DllCall("SetSystemCursor", "Ptr", hBackup, "Int", cursorType)
        }
        OldCursors := Map()
    } else if State = "Cleanup" {
        if BlankCursor {
            DllCall("DestroyCursor", "Ptr", BlankCursor)
            BlankCursor := 0
        }
    }
}