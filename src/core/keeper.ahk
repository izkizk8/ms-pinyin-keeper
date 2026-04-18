; ============================================================================
; Keeper — global EN/CN memory for Microsoft Pinyin
;
; Model:
;   - One bool g_DesiredEN persisted to ini.
;   - User Shift -> flip g_DesiredEN (we mirror their toggle).
;   - On focus change OR right after a user Shift, write the desired mode
;     directly to the focused window's IME via WM_IME_CONTROL /
;     IMC_SETCONVERSIONMODE. This is silent and idempotent — re-applying
;     "EN" to a window already in EN is a no-op, so it doesn't cause the
;     "random toggle" bug that Send Shift had.
;   - We re-apply for ~600ms after each event to win the race against
;     Pinyin's own per-window reset.
;
; No state reading: TSF-based Microsoft Pinyin doesn't answer the read,
; so we never know the current mode. Idempotent SET doesn't need to know.
; ============================================================================

global g_DesiredEN         := false
global g_KeeperRunning     := true
global g_PrevHwnd          := 0
global g_ReapplyUntilMs    := 0

KeeperInit() {
    global g_DesiredEN, g_PrevHwnd
    g_DesiredEN := (ConfigGet("desired_en", "0") = "1")
    try g_PrevHwnd := WinGetID("A")
    Hotkey("~LShift", KeeperOnUserShift)
    Hotkey("~RShift", KeeperOnUserShift)
    SetTimer(KeeperTick, 80)
    KeeperLog("init: desired=" . (g_DesiredEN ? "EN" : "CN"))
}

KeeperOnUserShift(*) {
    global g_DesiredEN, g_KeeperRunning, g_ReapplyUntilMs
    if !g_KeeperRunning
        return
    g_DesiredEN := !g_DesiredEN
    ConfigSet("desired_en", g_DesiredEN ? "1" : "0")
    KeeperLog("user shift -> " . (g_DesiredEN ? "EN" : "CN"))
    ; Reaffirm for a moment so Pinyin's own handler doesn't undo us.
    g_ReapplyUntilMs := A_TickCount + 400
}

KeeperTick() {
    global g_PrevHwnd, g_ReapplyUntilMs, g_KeeperRunning, g_DesiredEN
    if !g_KeeperRunning
        return
    hwnd := 0
    try hwnd := WinGetID("A")
    if !hwnd
        return
    if (hwnd != g_PrevHwnd) {
        g_PrevHwnd := hwnd
        g_ReapplyUntilMs := A_TickCount + 600
        KeeperLog("focus -> " . hwnd . " (" . KeeperWinTitle(hwnd) . "); desired=" . (g_DesiredEN ? "EN" : "CN"))
    }
    if (A_TickCount < g_ReapplyUntilMs)
        ApplyDesiredMode(hwnd)
}

; Write the desired conversion mode directly to the IME of the given window.
; Silent + idempotent: writing "CN" to a window already in CN is a no-op.
ApplyDesiredMode(hwnd) {
    global g_DesiredEN
    hIME := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", hwnd, "Ptr")
    if !hIME
        return false
    ; IME_CMODE_NATIVE = 1 (Chinese), 0 = English alphanumeric.
    mode := g_DesiredEN ? 0 : 1
    try SendMessage(0x283, 0x002, mode, , "ahk_id " . hIME, , , , 100)
    return true
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

KeeperLog(msg) {
    if (ConfigGet("debug", "0") != "1")
        return
    try FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") . " " . msg . "`n",
        KeeperLogPath(), "UTF-8")
}

KeeperLogPath() {
    return EnvGet("LOCALAPPDATA") . "\ms-pinyin-keeper\debug.log"
}
