; ============================================================================
; Keeper — globally remember EN/CN mode across window switches
;
; Strategy:
;  - Watch active-window changes (250ms tick).
;  - When user presses Shift, capture the *new* mode (they explicitly chose it).
;  - When focus moves to a new window whose mode differs from the desired
;    one, force the IME's conversion mode directly (no Shift simulation).
; ============================================================================

global g_DesiredMode   := ""    ; "" = unset, otherwise raw IME mode int
global g_PrevHwnd      := 0
global g_KeeperRunning := true

KeeperInit() {
    Hotkey("~LShift", KeeperOnShift)
    Hotkey("~RShift", KeeperOnShift)
    SetTimer(KeeperTick, 200)
}

KeeperOnShift(*) {
    ; Defer slightly so the IME has time to apply the new mode.
    SetTimer(KeeperCaptureNow, -120)
}

KeeperCaptureNow() {
    global g_DesiredMode, g_KeeperRunning
    if !g_KeeperRunning
        return
    hwnd := 0
    try hwnd := WinGetID("A")
    raw := GetIMEModeRaw(hwnd)
    if (raw != -1)
        g_DesiredMode := raw
}

KeeperTick() {
    global g_PrevHwnd, g_DesiredMode, g_KeeperRunning
    if !g_KeeperRunning
        return
    hwnd := 0
    try hwnd := WinGetID("A")
    if !hwnd
        return
    focusChanged := (hwnd != g_PrevHwnd)
    g_PrevHwnd := hwnd
    if (g_DesiredMode = "")
        return
    cur := GetIMEModeRaw(hwnd)
    if (cur = -1)
        return
    newMode := KeeperComputeNewMode(cur, g_DesiredMode)
    if (newMode = cur)
        return
    SetIMEModeRaw(hwnd, newMode)
    KeeperLog("hwnd=" . hwnd . " cur=" . cur . " desired=" . g_DesiredMode . " -> " . newMode)
}

; Pure function: given the window's current raw mode and the desired raw
; mode, return the mode we should write back. Only enforces the NATIVE bit
; (CN vs EN) — preserves the current window's other bits (full-shape etc.).
KeeperComputeNewMode(cur, desired) {
    desiredEN := !(desired & 1)
    curEN     := !(cur & 1)
    if (desiredEN = curEN)
        return cur
    return desiredEN ? (cur & ~1) : (cur | 1)
}

KeeperLog(msg) {
    static path := ""
    if (path = "") {
        base := EnvGet("LOCALAPPDATA") . "\ms-pinyin-keeper"
        path := base . "\debug.log"
    }
    if (ConfigGet("debug", "0") != "1")
        return
    try FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") . " " . msg . "`n", path, "UTF-8")
}

KeeperToggle() {
    global g_KeeperRunning
    g_KeeperRunning := !g_KeeperRunning
    return g_KeeperRunning
}

KeeperIsRunning() {
    global g_KeeperRunning
    return g_KeeperRunning
}
