; ============================================================================
; Config (ini in %LOCALAPPDATA%\ms-pinyin-keeper\)
; ============================================================================

global g_ConfigPath := ""

ConfigInit() {
    global g_ConfigPath
    base := EnvGet("LOCALAPPDATA") . "\ms-pinyin-keeper"
    if !DirExist(base)
        DirCreate(base)
    g_ConfigPath := base . "\config.ini"
    if !FileExist(g_ConfigPath) {
        IniWrite("0", g_ConfigPath, "general", "auto_update")
    }
}

ConfigGet(key, default := "") {
    global g_ConfigPath
    try {
        return IniRead(g_ConfigPath, "general", key, default)
    } catch {
        return default
    }
}

ConfigSet(key, value) {
    global g_ConfigPath
    IniWrite(value, g_ConfigPath, "general", key)
}
