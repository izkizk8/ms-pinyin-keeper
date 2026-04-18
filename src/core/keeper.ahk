; ============================================================================
; Keeper — global EN/CN memory for Microsoft Pinyin
;
; How it actually works (thanks to InputTip / Tebayaki for the discovery):
;   - For Microsoft Pinyin (and most modern IMEs), EN/CN is reflected in
;     IMC_GETOPENSTATUS (WM_IME_CONTROL wParam=0x5):
;        OPEN  = 1 -> Chinese input mode
;        OPEN  = 0 -> English direct mode
;     Unlike IMC_GETCONVERSIONMODE which is unreliable on TSF apps,
;     OPENSTATUS works for Notepad, Windows Terminal, browsers, VS Code,
;     File Explorer, etc.
;   - To actually find the focused control inside a foreground app
;     (matters for browsers / Electron / VS Code), use GetGUIThreadInfo.
;
; Algorithm:
;   1. Poll focused window (every 100ms).
;   2. Read its real EN/CN via IMC_GETOPENSTATUS.
;   3. If real != desired, set it via IMC_SETOPENSTATUS + (for CN) set
;      conversion mode to 1025 (Native + Symbol) for Pinyin.
;   4. User clean Shift tap (no other key + short) flips g_DesiredEN.
; ============================================================================

global g_DesiredEN         := false
global g_KeeperRunning     := true
global g_ShiftDownTick     := 0
global g_LastFixTick       := Map()    ; hwnd -> A_TickCount of last fix attempt
global g_InternalSendTick  := 0        ; suppress our own Shift from hotkey

KeeperInit() {
    global g_DesiredEN
    g_DesiredEN := (ConfigGet("desired_en", "0") = "1")
    InstallKeybdHook(true)
    Hotkey("~LShift", KeeperOnShiftDown)
    Hotkey("~LShift Up", KeeperOnShiftUp)
    Hotkey("~RShift", KeeperOnShiftDown)
    Hotkey("~RShift Up", KeeperOnShiftUp)
    SetTimer(KeeperTick, 200)
    KeeperLog("init: desired=" . (g_DesiredEN ? "EN" : "CN"))
}

KeeperOnShiftDown(*) {
    global g_ShiftDownTick, g_InternalSendTick
    ; Ignore our own injected Shift.
    if (A_TickCount - g_InternalSendTick < 600)
        return
    g_ShiftDownTick := A_TickCount
}

KeeperOnShiftUp(*) {
    global g_DesiredEN, g_KeeperRunning, g_ShiftDownTick, g_InternalSendTick
    if !g_KeeperRunning
        return
    if (A_TickCount - g_InternalSendTick < 600)
        return
    if (g_ShiftDownTick = 0 || A_TickCount - g_ShiftDownTick > 500)
        return
    pk := A_PriorKey
    if (pk != "LShift" && pk != "RShift")
        return
    g_DesiredEN := !g_DesiredEN
    ConfigSet("desired_en", g_DesiredEN ? "1" : "0")
    KeeperLog("user shift -> " . (g_DesiredEN ? "EN" : "CN"))
}

KeeperTick() {
    global g_DesiredEN, g_KeeperRunning, g_LastFixTick
    if !g_KeeperRunning
        return
    hwnd := GetFocusedHwnd()
    if !hwnd
        return
    ; Skip Pinyin's own UI windows (candidate window, status bar, etc.)
    if IsImeOwnWindow(hwnd)
        return
    real := IME_GetOpenStatus(hwnd)
    if (real = -1)
        return
    realEN := (real = 0)
    if (realEN = g_DesiredEN)
        return
    last := g_LastFixTick.Has(hwnd) ? g_LastFixTick[hwnd] : 0
    if (A_TickCount - last < 1500)
        return
    g_LastFixTick[hwnd] := A_TickCount
    title := KeeperWinTitle(hwnd)
    KeeperLog("fix " . hwnd . " (" . title . "): real=" . (realEN ? "EN" : "CN")
        . " -> " . (g_DesiredEN ? "EN" : "CN"))
    ok := FixMode(hwnd)
    if !ok
        g_LastFixTick[hwnd] := A_TickCount + 8000  ; back off ~10s for stuck windows
}

; Try to bring `hwnd` to g_DesiredEN. Strategy:
;   1. Send Shift (the only thing that reliably flips Pinyin TSF). It's a
;      simple toggle — since we just confirmed real != desired, ONE Shift
;      sends us in the right direction.
;   2. Belt-and-suspenders: also issue the silent SetOpenStatus.
;   3. Re-read after a beat; if still wrong, log a warning (don't loop).
FixMode(hwnd) {
    global g_DesiredEN, g_InternalSendTick
    g_InternalSendTick := A_TickCount
    IME_SetOpenStatus(hwnd, g_DesiredEN ? 0 : 1)
    Sleep 40
    real := IME_GetOpenStatus(hwnd)
    if (real != -1 && (real = 0) = g_DesiredEN) {
        KeeperLog("  -> set OK via SetOpenStatus")
        return true
    }
    ; SendInput {LShift}: Pinyin's "Shift toggles CN/EN" handler accepts this.
    ; Our hotkey ignores it via the g_InternalSendTick guard.
    try SendInput("{LShift}")
    Sleep 80
    real2 := IME_GetOpenStatus(hwnd)
    if (real2 != -1) {
        ok := ((real2 = 0) = g_DesiredEN)
        KeeperLog("  -> after Shift: real=" . (real2 = 0 ? "EN" : "CN")
            . (ok ? " OK" : " STILL WRONG"))
        return ok
    }
    return false
}

; True if hwnd belongs to a Pinyin IME process — those windows always report
; CN and don't actually accept conversion-mode changes.
IsImeOwnWindow(hwnd) {
    pid := 0
    try pid := WinGetPID("ahk_id " . hwnd)
    if !pid
        return false
    try {
        name := ProcessGetName(pid)
        if (name = "ChsIME.exe" || name = "InputApp.exe" || name = "ImeBroker.exe"
            || name = "TabTip.exe" || name = "MsCtfMonitor.exe")
            return true
    }
    return false
}

; --- IME helpers (WM_IME_CONTROL) -------------------------------------------

IME_GetOpenStatus(hwnd) {
    hIME := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", hwnd, "Ptr")
    if !hIME
        return -1
    status := 0
    ok := DllCall("SendMessageTimeoutW",
        "Ptr", hIME, "UInt", 0x283, "Ptr", 0x5, "Ptr", 0,
        "UInt", 0, "UInt", 100, "Ptr*", &status)
    if !ok
        return -1
    return status ? 1 : 0
}

IME_SetOpenStatus(hwnd, openStatus) {
    hIME := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", hwnd, "Ptr")
    if !hIME
        return false
    DllCall("SendMessageTimeoutW",
        "Ptr", hIME, "UInt", 0x283, "Ptr", 0x6, "Ptr", openStatus,
        "UInt", 0, "UInt", 100, "Ptr*", 0)
    if openStatus {
        hkl := DllCall("GetKeyboardLayout", "UInt",
            DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt"), "Ptr")
        cm := ((hkl & 0xFFFF) = 0x0804) ? 1025 : 1
        DllCall("SendMessageTimeoutW",
            "Ptr", hIME, "UInt", 0x283, "Ptr", 0x2, "Ptr", cm,
            "UInt", 0, "UInt", 100, "Ptr*", 0)
    }
    return true
}

; Returns the focused control inside the foreground app (matters for
; browsers/VSCode/Electron), falling back to the foreground window.
GetFocusedHwnd() {
    fg := 0
    try fg := WinGetID("A")
    if !fg
        return 0
    size := A_PtrSize = 8 ? 72 : 48
    buf := Buffer(size, 0)
    NumPut("UInt", size, buf)
    tid := DllCall("GetWindowThreadProcessId", "Ptr", fg, "Ptr", 0, "UInt")
    if DllCall("GetGUIThreadInfo", "UInt", tid, "Ptr", buf) {
        focused := NumGet(buf, A_PtrSize = 8 ? 16 : 12, "Ptr")
        if focused
            return focused
    }
    return fg
}

KeeperWinTitle(hwnd) {
    t := ""
    try t := WinGetTitle("ahk_id " . hwnd)
    return SubStr(t, 1, 60)
}

KeeperToggle() {
    global g_KeeperRunning
    g_KeeperRunning := !g_KeeperRunning
    KeeperLog("keeper " . (g_KeeperRunning ? "resumed" : "paused"))
    return g_KeeperRunning
}

KeeperIsRunning() {
    global g_KeeperRunning
    return g_KeeperRunning
}

; --- Logging ----------------------------------------------------------------

KeeperLog(msg) {
    if (ConfigGet("debug", "0") = "0")
        return
    try FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") . " " . msg . "`n",
        KeeperLogPath(), "UTF-8")
}

KeeperLogPath() {
    return EnvGet("LOCALAPPDATA") . "\ms-pinyin-keeper\debug.log"
}
