; ============================================================================
; Autostart via HKCU\...\Run
; ============================================================================

global REG_RUN       := "HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
global APP_REG_NAME  := "ms-pinyin-keeper"

AutostartIsEnabled() {
    try {
        v := RegRead(REG_RUN, APP_REG_NAME)
        return v != ""
    } catch {
        return false
    }
}

AutostartEnable() {
    ; Run AHK directly to avoid the cmd window flash from .bat
    cmd := '"' . A_AhkPath . '" "' . A_ScriptFullPath . '"'
    RegWrite(cmd, "REG_SZ", REG_RUN, APP_REG_NAME)
}

AutostartDisable() {
    try RegDelete(REG_RUN, APP_REG_NAME)
}

AutostartToggle() {
    if AutostartIsEnabled() {
        AutostartDisable()
        return false
    } else {
        AutostartEnable()
        return true
    }
}
