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
    M.Add("About", (*) => TrayAbout())
    M.Add("Exit", (*) => ExitApp())
}

TrayNoop(*) {
}

TrayUpdateIcon() {
    global APP_NAME, APP_VERSION
    A_IconTip := APP_NAME . " v" . APP_VERSION
        . (KeeperIsRunning() ? " (running)" : " (paused)")
}

TrayToggle() {
    global APP_NAME
    running := KeeperToggle()
    TrayUpdateIcon()
    TrayTip(running ? "Resumed" : "Paused", APP_NAME, 0x10)
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

TrayAbout() {
    global APP_NAME, APP_VERSION, APP_REPO
    MsgBox(APP_NAME . " v" . APP_VERSION
        . "`n`nMake Microsoft Pinyin remember EN/CN mode globally."
        . "`n`nhttps://github.com/" . APP_REPO,
        "About", 0x40)
}
