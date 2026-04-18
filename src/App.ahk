; ============================================================================
; ms-pinyin-keeper — entry point
; ============================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force

global APP_NAME    := "ms-pinyin-keeper"
global APP_VERSION := Trim(FileRead(A_ScriptDir . "\version.txt", "UTF-8"), " `t`r`n")
global APP_REPO    := "izkizk8/ms-pinyin-keeper"

#Include utils\ini.ahk
#Include utils\autostart.ahk
#Include core\keeper.ahk
#Include core\tray.ahk
#Include update\updater.ahk

ConfigInit()
TrayInit()
KeeperInit()

; First-run autostart prompt skipped; user opts in via tray.

; If auto-update is enabled, schedule a check shortly after start and every 24h.
if (ConfigGet("auto_update", "0") = "1") {
    SetTimer(UpdaterCheckAuto, -3000)
    SetTimer(UpdaterCheckAuto, 24 * 60 * 60 * 1000)
}

Persistent
