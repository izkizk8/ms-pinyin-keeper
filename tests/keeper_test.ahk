; ============================================================================
; Unit tests for keeper logic
; Run with:  AutoHotkey64.exe tests\keeper_test.ahk
; Exits 0 on success, 1 on failure (CI-friendly).
; ============================================================================
#Requires AutoHotkey v2.0
#NoTrayIcon

; Stub the Config + Log dependencies so we can include keeper.ahk standalone.
ConfigGet(k, d := "") => d
GetIMEModeRaw(hwnd) => -1
SetIMEModeRaw(hwnd, mode) => true

#Include ..\src\core\keeper.ahk

failures := 0
total    := 0

Assert(name, got, want) {
    global failures, total
    total += 1
    if (got = want) {
        FileAppend("ok   - " . name . "`n", "*")
    } else {
        failures += 1
        FileAppend("FAIL - " . name . " got=" . got . " want=" . want . "`n", "*")
    }
}

Assert("CN(1)->EN basic",            KeeperComputeNewMode(1, 0),       0)
Assert("EN(0)->CN basic",            KeeperComputeNewMode(0, 1),       1)
Assert("EN->EN noop",                KeeperComputeNewMode(0, 0),       0)
Assert("CN->CN noop",                KeeperComputeNewMode(1, 1),       1)
Assert("CN(1025)->EN preserves",     KeeperComputeNewMode(1025, 0),    1024)
Assert("EN(1024)->CN preserves",     KeeperComputeNewMode(1024, 1),    1025)
Assert("desired native via 1024",    KeeperComputeNewMode(1, 1024),    0)
Assert("desired native via 1025",    KeeperComputeNewMode(0, 1025),    1)

if (failures > 0) {
    FileAppend("`n" . failures . "/" . total . " tests FAILED`n", "*")
    ExitApp(1)
}
FileAppend("`nAll " . total . " tests passed.`n", "*")
ExitApp(0)
