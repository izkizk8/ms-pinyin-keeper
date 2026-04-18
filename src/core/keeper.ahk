; ============================================================================
; Keeper — global EN/CN memory for Microsoft Pinyin
;
; Premise: Microsoft Pinyin resets to CN on every window focus change.
; We track the user's last-chosen mode in a single boolean (g_DesiredEN)
; and, on every focus change, send a real {LShift} if needed to flip
; the new window from Pinyin's just-applied CN back to EN.
;
; No IME state reading — that path doesn't work for TSF Pinyin and was
; the source of all earlier bugs. The model is: user toggles via Shift,
; we mirror that toggle, and re-apply it whenever focus changes.
; ============================================================================

global g_DesiredEN          := false   ; true = English, false = Chinese
global g_KeeperRunning      := true
global g_PrevHwnd           := 0
global g_LastInternalSendMs := 0

KeeperInit() {
    global g_DesiredEN, g_PrevHwnd
    g_DesiredEN := (ConfigGet("desired_en", "0") = "1")
    try g_PrevHwnd := WinGetID("A")

    Hotkey("~LShift", KeeperOnUserShift)
    Hotkey("~RShift", KeeperOnUserShift)
    SetTimer(KeeperWatchFocus, 100)
    KeeperLog("init: desired=" . (g_DesiredEN ? "EN" : "CN"))
}

; The user pressed Shift themselves -> they toggled the IME.
; AHK's hook ignores its own SendInput, so this only fires for real keys.
KeeperOnUserShift(*) {
    global g_DesiredEN, g_KeeperRunning, g_LastInternalSendMs
    if !g_KeeperRunning
        return
    ; Belt-and-suspenders: also ignore a brief window after our own send.
    if (A_TickCount - g_LastInternalSendMs < 250)
        return
    g_DesiredEN := !g_DesiredEN
    ConfigSet("desired_en", g_DesiredEN ? "1" : "0")
    KeeperLog("user toggled -> " . (g_DesiredEN ? "EN" : "CN"))
}

KeeperWatchFocus() {
    global g_PrevHwnd, g_DesiredEN, g_KeeperRunning, g_LastInternalSendMs
    if !g_KeeperRunning
        return
    hwnd := 0
    try hwnd := WinGetID("A")
    if (!hwnd || hwnd = g_PrevHwnd)
        return
    g_PrevHwnd := hwnd
    KeeperLog("focus -> " . hwnd . " (" . KeeperWinTitle(hwnd) . "); desired=" . (g_DesiredEN ? "EN" : "CN"))
    ; Pinyin just reset this new window to CN. If we want EN, flip it.
    if g_DesiredEN {
        g_LastInternalSendMs := A_TickCount
        try Send("{Blind}{LShift}")
        KeeperLog("  sent Shift to restore EN")
    }
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

KeeperGetDesired() {
    global g_DesiredEN
    return g_DesiredEN
}

; Manual override: tray menu can let user resync without pressing Shift.
KeeperSetDesired(en) {
    global g_DesiredEN
    g_DesiredEN := !!en
    ConfigSet("desired_en", g_DesiredEN ? "1" : "0")
    KeeperLog("desired set to " . (g_DesiredEN ? "EN" : "CN") . " (manual)")
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
