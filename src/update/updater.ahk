; ============================================================================
; Updater — check GitHub Releases, download zip, hand off to helper bat
; ============================================================================

UpdaterCheckAuto() {
    UpdaterCheck(true)
}

UpdaterCheckManual() {
    UpdaterCheck(false)
}

UpdaterCheck(silent) {
    global APP_VERSION, APP_REPO, APP_NAME
    try {
        url := "https://api.github.com/repos/" . APP_REPO . "/releases/latest"
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        http.Open("GET", url, false)
        http.SetRequestHeader("User-Agent", APP_NAME . "/" . APP_VERSION)
        http.SetRequestHeader("Accept", "application/vnd.github+json")
        http.Send()
        body := http.ResponseText

        if !RegExMatch(body, '"tag_name"\s*:\s*"([^"]+)"', &m) {
            if !silent
                MsgBox("No releases found.", "Check for updates", 0x30)
            return
        }
        latest := RegExReplace(m[1], "^v", "")
        if (CompareVersion(latest, APP_VERSION) <= 0) {
            if !silent
                MsgBox("You are on the latest version (v" . APP_VERSION . ").", "Check for updates", 0x40)
            return
        }

        if !RegExMatch(body, '"browser_download_url"\s*:\s*"([^"]+\.zip)"', &m2) {
            if !silent
                MsgBox("New version v" . latest . " found, but no zip asset.", "Check for updates", 0x30)
            return
        }
        zipUrl := m2[1]

        result := MsgBox("New version v" . latest . " is available.`nCurrent: v" . APP_VERSION
            . "`n`nDownload and install now?", "Update available", 0x44 | 0x40)
        if (result != "Yes")
            return

        UpdaterDownloadAndApply(zipUrl)
    } catch as e {
        if !silent
            MsgBox("Update check failed: " . e.Message, "Check for updates", 0x10)
    }
}

CompareVersion(a, b) {
    pa := StrSplit(a, ".")
    pb := StrSplit(b, ".")
    Loop 3 {
        x := A_Index <= pa.Length ? Integer(pa[A_Index]) : 0
        y := A_Index <= pb.Length ? Integer(pb[A_Index]) : 0
        if (x > y)
            return 1
        if (x < y)
            return -1
    }
    return 0
}

UpdaterDownloadAndApply(zipUrl) {
    tmp := A_Temp . "\ms-pinyin-keeper-update"
    if DirExist(tmp)
        DirDelete(tmp, true)
    DirCreate(tmp)
    zipPath := tmp . "\release.zip"
    Download(zipUrl, zipPath)

    extractDir := tmp . "\extracted"
    DirCreate(extractDir)
    ; Synchronous extraction via PowerShell (Expand-Archive is reliable on Win10+)
    psCmd := 'Expand-Archive -Path "' . zipPath . '" -DestinationPath "' . extractDir . '" -Force'
    RunWait('powershell -NoProfile -ExecutionPolicy Bypass -Command "' . psCmd . '"', , "Hide")

    inner := ""
    Loop Files, extractDir . "\*", "D" {
        inner := A_LoopFileFullPath
        break
    }
    if (inner = "") {
        MsgBox("Update extraction failed: no inner folder.", "Update", 0x10)
        return
    }

    appRoot := A_ScriptDir . "\.."
    helper  := A_ScriptDir . "\update\update-helper.bat"
    pid     := ProcessExist()
    Run('cmd /c ""' . helper . '" "' . inner . '" "' . appRoot . '" ' . pid . '"', , "Hide")
    ExitApp()
}
