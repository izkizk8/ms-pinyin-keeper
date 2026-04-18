; ============================================================================
; Tray icon + menu
; ============================================================================

TrayInit() {
    global APP_NAME, APP_VERSION
    TrayUpdateIcon()

    M := A_TrayMenu
    M.Delete()
    M.Add(APP_NAME . " v" . APP_VERSION, TrayNoop)
    M.Disable(APP_NAME . " v" . APP_VERSION)
    M.Add()
    M.Add("Pause / Resume", (*) => TrayToggle())
    M.Default := "Pause / Resume"
    M.Add()
    M.Add("Run at startup", (*) => TrayToggleAutostart())
    if AutostartIsEnabled()
        M.Check("Run at startup")
    M.Add("Auto check for updates", (*) => TrayToggleAutoUpdate())
    if (ConfigGet("auto_update", "0") = "1")
        M.Check("Auto check for updates")
    M.Add("Check for updates now", (*) => UpdaterCheckManual())
    M.Add()
    M.Add("Debug log", (*) => TrayToggleDebug())
    if (ConfigGet("debug", "0") = "1")
        M.Check("Debug log")
    M.Add("Open debug log folder", (*) => TrayOpenLogFolder())
    M.Add()
    M.Add("About", (*) => TrayAbout())
    M.Add("Exit", (*) => ExitApp())

    ; AHK_NOTIFYICON = 0x404; intercept tray clicks so left-click toggles
    ; pause/resume (Menu.Default in AHK v2 only fires on double-click).
    OnMessage(0x404, TrayOnNotify)
}

; lParam tells us which mouse event happened on the tray icon.
;   WM_LBUTTONUP   = 0x202
;   WM_LBUTTONDBLCLK = 0x203
;   WM_RBUTTONUP   = 0x205
TrayOnNotify(wParam, lParam, msg, hwnd) {
    static WM_LBUTTONUP := 0x202
    static WM_RBUTTONUP := 0x205
    if (lParam = WM_LBUTTONUP) {
        TrayToggle()
        return 0
    }
    if (lParam = WM_RBUTTONUP) {
        try A_TrayMenu.Show()
        return 0
    }
    ; Let AHK handle other notifications (double-click → Default item, etc.)
}

TrayNoop(*) {
}

TrayUpdateIcon() {
    global APP_NAME, APP_VERSION
    A_IconTip := APP_NAME . " v" . APP_VERSION
        . (KeeperIsRunning() ? " (running)" : " (paused)")
    ; Visually indicate paused state by hiding the tray icon's animation —
    ; AHK has no built-in "gray" icon, so we rely on tooltip + balloon.
}

TrayToggle() {
    global APP_NAME
    running := KeeperToggle()
    TrayUpdateIcon()
    try TrayTip(running ? "Resumed" : "Paused", APP_NAME, 0x10)
}

TrayToggleAutostart() {
    enabled := AutostartToggle()
    if enabled
        A_TrayMenu.Check("Run at startup")
    else
        A_TrayMenu.Uncheck("Run at startup")
}

TrayToggleAutoUpdate() {
    cur := ConfigGet("auto_update", "0") = "1"
    new := !cur
    ConfigSet("auto_update", new ? "1" : "0")
    if new
        A_TrayMenu.Check("Auto check for updates")
    else
        A_TrayMenu.Uncheck("Auto check for updates")
}

TrayToggleDebug() {
    global APP_NAME
    cur := ConfigGet("debug", "0") = "1"
    new := !cur
    ConfigSet("debug", new ? "1" : "0")
    if new {
        A_TrayMenu.Check("Debug log")
        try TrayTip("Debug log enabled`n" . KeeperLogPath(), APP_NAME, 0x10)
    } else {
        A_TrayMenu.Uncheck("Debug log")
        try TrayTip("Debug log disabled", APP_NAME, 0x10)
    }
}

TrayOpenLogFolder() {
    folder := EnvGet("LOCALAPPDATA") . "\ms-pinyin-keeper"
    if !DirExist(folder)
        DirCreate(folder)
    try Run('explorer.exe "' . folder . '"')
}

TrayAbout() {
    global APP_NAME, APP_VERSION, APP_REPO
    MsgBox(APP_NAME . " v" . APP_VERSION
        . "`n`nMake Microsoft Pinyin remember EN/CN mode globally."
        . "`n`nhttps://github.com/" . APP_REPO,
        "About", 0x40)
}
