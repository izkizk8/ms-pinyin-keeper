; ============================================================================
; Keeper — global EN/CN memory for Microsoft Pinyin
;
; Model:
;   - One bool g_DesiredEN persisted to ini, mirrors the user's Shift toggles.
;   - For each hwnd we've seen, we remember our believed mode for it.
;     New windows are assumed to start in CN (Pinyin's default).
;   - On focus change, if believed[hwnd] != desired, we:
;       (1) try a silent IMC_SETCONVERSIONMODE write (works for IMM32 apps
;           like Notepad — no key event, no toggle ambiguity), and
;       (2) Send Shift (the only thing that works for TSF apps like Windows
;           Terminal, VS Code, browsers).
;     Then update believed[hwnd] = desired. We do NOT touch a window we
;     already believe is in the desired mode — this is what fixed the
;     "two notepads were random" bug.
;   - When the user presses Shift while focused on a window, we flip both
;     g_DesiredEN and believed[currentHwnd] (Shift just changed both).
;
; Caveat: if Pinyin silently resets a TSF window's mode behind our back
; (e.g. user Alt-Tab away and back many times), our belief becomes stale.
; In practice TSF Pinyin retains per-window mode once it has been set, so
; one corrective Shift on first visit is enough.
; ============================================================================

global g_DesiredEN         := false
global g_KeeperRunning     := true
global g_PrevHwnd          := 0
global g_WindowModes       := Map()           ; hwnd -> believed mode: true=EN, false=CN

KeeperInit() {
    global g_DesiredEN, g_PrevHwnd
    g_DesiredEN := (ConfigGet("desired_en", "0") = "1")
    ; #InputLevel 0 (default) for hotkey; we Send at level 1 so the hotkey
    ; won't see our own Shift. (The ~ prefix keeps the user's Shift native.)
    Hotkey("~LShift", KeeperOnUserShift)
    Hotkey("~RShift", KeeperOnUserShift)
    SetTimer(KeeperTick, 100)
    KeeperLog("init: desired=" . (g_DesiredEN ? "EN" : "CN"))
    g_PrevHwnd := 0   ; force initial correction on first tick
}

KeeperOnUserShift(*) {
    global g_DesiredEN, g_KeeperRunning, g_WindowModes
    if !g_KeeperRunning
        return
    g_DesiredEN := !g_DesiredEN
    ConfigSet("desired_en", g_DesiredEN ? "1" : "0")
    hwnd := 0
    try hwnd := WinGetID("A")
    if hwnd
        g_WindowModes[hwnd] := g_DesiredEN
    KeeperLog("user shift -> " . (g_DesiredEN ? "EN" : "CN"))
}

KeeperTick() {
    global g_PrevHwnd, g_KeeperRunning
    if !g_KeeperRunning
        return
    hwnd := 0
    try hwnd := WinGetID("A")
    if !hwnd
        return
    if (hwnd = g_PrevHwnd)
        return
    g_PrevHwnd := hwnd
    OnFocusChanged(hwnd)
}

OnFocusChanged(hwnd) {
    global g_DesiredEN, g_WindowModes
    believed := g_WindowModes.Has(hwnd) ? g_WindowModes[hwnd] : false  ; new window: assume CN
    title := KeeperWinTitle(hwnd)
    if (believed = g_DesiredEN) {
        KeeperLog("focus -> " . hwnd . " (" . title . "); already=" . (believed ? "EN" : "CN") . " — skip")
        return
    }
    KeeperLog("focus -> " . hwnd . " (" . title . "); believed=" . (believed ? "EN" : "CN")
        . " desired=" . (g_DesiredEN ? "EN" : "CN") . " — correcting")
    ; (1) Silent set via WM_IME_CONTROL — works on IMM32 apps, no-op on TSF.
    hIME := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", hwnd, "Ptr")
    if hIME {
        mode := g_DesiredEN ? 0 : 1
        try SendMessage(0x283, 0x002, mode, , "ahk_id " . hIME, , , , 80)
    }
    ; (2) Send Shift — works on TSF apps. SendLevel 1 ensures our own Shift
    ; is filtered out by the ~LShift hotkey (which lives at #InputLevel 0).
    prevLevel := A_SendLevel
    SendLevel 1
    try SendInput("{LShift}")
    SendLevel prevLevel
    g_WindowModes[hwnd] := g_DesiredEN
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
