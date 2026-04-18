; ============================================================================
; Keeper — record desired EN/CN mode on Shift, restore on focus change
; ============================================================================

global g_DesiredMode   := ""    ; "" unset, 0 = EN, 1 = CN
global g_PrevHwnd      := 0
global g_KeeperRunning := true

KeeperInit() {
    Hotkey("~LShift", KeeperOnShift)
    Hotkey("~RShift", KeeperOnShift)
    SetTimer(KeeperTick, 250)
}

KeeperOnShift(*) {
    ; Defer 150ms so the IME has time to apply the new mode
    SetTimer(KeeperCaptureNow, -150)
}

KeeperCaptureNow() {
    global g_DesiredMode, g_KeeperRunning
    if !g_KeeperRunning
        return
    m := GetIMEMode(WinGetID("A"))
    if (m != -1)
        g_DesiredMode := m
}

KeeperTick() {
    global g_PrevHwnd, g_DesiredMode, g_KeeperRunning
    if !g_KeeperRunning
        return
    hwnd := 0
    try hwnd := WinGetID("A")
    if (!hwnd || hwnd = g_PrevHwnd)
        return
    g_PrevHwnd := hwnd
    if (g_DesiredMode = "")
        return
    cur := GetIMEMode(hwnd)
    ; Skip windows where we cannot read state (UWP, sandboxed, etc.)
    if (cur = -1 || cur = g_DesiredMode)
        return
    ; Mode mismatch → simulate Shift to flip
    Send("{LShift}")
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
