; ============================================================================
; Keeper — globally remember EN/CN mode across window switches
;
; Strategy: poll the foreground window every ~120ms. If its IME's NATIVE
; bit (CN vs EN) doesn't match the user's last explicit choice, force it
; back. We try two methods in order:
;   1. WM_IME_CONTROL / IMC_SETCONVERSIONMODE  (silent, IMM API)
;   2. SendInput "{LShift}"                    (real keystroke fallback)
; The user's choice is captured whenever they press Shift themselves.
; ============================================================================

global g_DesiredMode         := ""    ; "" = unset, otherwise raw IME mode int
global g_PrevHwnd            := 0
global g_KeeperRunning       := true
global g_LastInternalSendMs  := 0

KeeperInit() {
    Hotkey("~LShift", KeeperOnShift)
    Hotkey("~RShift", KeeperOnShift)
    SetTimer(KeeperTick, 120)
}

KeeperOnShift(*) {
    SetTimer(KeeperCaptureNow, -130)
}

KeeperCaptureNow() {
    global g_DesiredMode, g_KeeperRunning, g_LastInternalSendMs
    if !g_KeeperRunning
        return
    ; Ignore captures right after our own internal Send Shift — that key was
    ; simulated by us, not chosen by the user.
    if (A_TickCount - g_LastInternalSendMs < 350)
        return
    hwnd := 0
    try hwnd := WinGetID("A")
    raw := GetIMEModeRaw(hwnd)
    if (raw != -1) {
        old := g_DesiredMode
        g_DesiredMode := raw
        KeeperLog("user shift: hwnd=" . hwnd . " mode=" . raw . " (was " . old . ")")
    }
}

KeeperTick() {
    global g_PrevHwnd, g_DesiredMode, g_KeeperRunning, g_LastInternalSendMs
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
    if !KeeperNeedsCorrection(cur, g_DesiredMode)
        return

    newMode := KeeperComputeNewMode(cur, g_DesiredMode)
    if focusChanged
        KeeperLog("focus changed -> " . hwnd . "; correcting " . cur . " -> " . newMode)

    ; --- Attempt 1: silent IME mode write -----------------------------------
    SetIMEModeRaw(hwnd, newMode)
    Sleep(25)
    cur2 := GetIMEModeRaw(hwnd)
    if (cur2 != -1 && !KeeperNeedsCorrection(cur2, g_DesiredMode))
        return

    ; --- Attempt 2: simulate Shift (user-equivalent toggle) -----------------
    KeeperLog("WM_IME_CONTROL ineffective (cur2=" . cur2 . "); falling back to Send Shift")
    g_LastInternalSendMs := A_TickCount
    try Send("{Blind}{LShift}")
    Sleep(40)
    cur3 := GetIMEModeRaw(hwnd)
    KeeperLog("after Shift: cur3=" . cur3)
}

; Pure: does the current raw mode disagree with desired on the NATIVE bit?
KeeperNeedsCorrection(cur, desired) {
    return (!(cur & 1)) != (!(desired & 1))
}

; Pure: compute the mode to write back (preserves cur's non-NATIVE bits).
KeeperComputeNewMode(cur, desired) {
    if !KeeperNeedsCorrection(cur, desired)
        return cur
    return (desired & 1) ? (cur | 1) : (cur & ~1)
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

; Reset desired mode (forget last user choice). Used after toggling debug etc.
KeeperResetDesired() {
    global g_DesiredMode
    g_DesiredMode := ""
}

KeeperLog(msg) {
    static path := EnvGet("LOCALAPPDATA") . "\ms-pinyin-keeper\debug.log"
    if (ConfigGet("debug", "0") != "1")
        return
    try FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") . " " . msg . "`n", path, "UTF-8")
}

KeeperLogPath() {
    return EnvGet("LOCALAPPDATA") . "\ms-pinyin-keeper\debug.log"
}
