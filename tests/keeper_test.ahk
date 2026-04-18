; ============================================================================
; Unit tests for keeper logic
; Run with:  AutoHotkey64.exe tests\keeper_test.ahk
; Exits 0 on success, 1 on failure (CI-friendly).
; ============================================================================
#Requires AutoHotkey v2.0
#NoTrayIcon

; --- Stubs for keeper.ahk's external deps --------------------------------
; Mocked IME state — manipulated by tests.
global g_MockMode := -1
global g_SetCalls := []

ConfigGet(k, d := "") => d
GetIMEModeRaw(hwnd) => g_MockMode
SetIMEModeRaw(hwnd, mode) {
    global g_MockMode, g_SetCalls
    g_SetCalls.Push(mode)
    g_MockMode := mode
    return true
}
WinGetID(t) => 0x12345

#Include ..\src\core\keeper.ahk

failures := 0
total    := 0

Assert(name, got, want) {
    global failures, total
    total += 1
    line := (got = want ? "ok   - " : "FAIL - ") . name
        . " got=" . got . " want=" . want . "`n"
    if (got != want)
        failures += 1
    FileAppend(line, A_ScriptDir . "\test_results.log", "UTF-8")
}

; ---- KeeperComputeNewMode ------------------------------------------------
Assert("CN(1)->EN basic",          KeeperComputeNewMode(1, 0),       0)
Assert("EN(0)->CN basic",          KeeperComputeNewMode(0, 1),       1)
Assert("EN->EN noop",              KeeperComputeNewMode(0, 0),       0)
Assert("CN->CN noop",              KeeperComputeNewMode(1, 1),       1)
Assert("CN(1025)->EN preserves",   KeeperComputeNewMode(1025, 0),    1024)
Assert("EN(1024)->CN preserves",   KeeperComputeNewMode(1024, 1),    1025)
Assert("desired-bit via 1024",     KeeperComputeNewMode(1, 1024),    0)
Assert("desired-bit via 1025",     KeeperComputeNewMode(0, 1025),    1)

; ---- KeeperNeedsCorrection -----------------------------------------------
Assert("needs CN!=EN",             KeeperNeedsCorrection(1, 0),      true)
Assert("needs EN!=CN",             KeeperNeedsCorrection(0, 1),      true)
Assert("no need EN==EN",           KeeperNeedsCorrection(0, 0),      false)
Assert("no need CN==CN",           KeeperNeedsCorrection(1, 1),      false)
Assert("no need 1024 vs 0",        KeeperNeedsCorrection(1024, 0),   false)
Assert("needs 1025 vs 0",          KeeperNeedsCorrection(1025, 0),   true)

; ---- Integration: KeeperTick triggers SetIMEModeRaw on mismatch ----------
g_DesiredMode := 0       ; user wants EN
g_MockMode    := 1       ; window is CN
g_PrevHwnd    := 0
g_SetCalls    := []
KeeperTick()
Assert("tick wrote 0 on CN window",  g_SetCalls.Length >= 1 ? g_SetCalls[1] : -99,  0)
Assert("tick fixed mode to EN",      g_MockMode,                                    0)

; Already matching → no write.
g_DesiredMode := 0
g_MockMode    := 0
g_PrevHwnd    := 0
g_SetCalls    := []
KeeperTick()
Assert("tick noop when matched",     g_SetCalls.Length,                              0)

; Desired unset → no write even if mock mode is CN.
g_DesiredMode := ""
g_MockMode    := 1
g_PrevHwnd    := 0
g_SetCalls    := []
KeeperTick()
Assert("tick noop when desired unset", g_SetCalls.Length,                            0)

; Paused → no write.
g_KeeperRunning := false
g_DesiredMode   := 0
g_MockMode      := 1
g_SetCalls      := []
KeeperTick()
Assert("tick noop when paused",       g_SetCalls.Length,                             0)
g_KeeperRunning := true

; Toggle returns new state.
g_KeeperRunning := true
Assert("toggle off",                  KeeperToggle(),                                false)
Assert("toggle on",                   KeeperToggle(),                                true)

if (failures > 0) {
    FileAppend("`n" . failures . "/" . total . " tests FAILED`n", A_ScriptDir . "\test_results.log", "UTF-8")
    ExitApp(1)
}
FileAppend("`nAll " . total . " tests passed.`n", A_ScriptDir . "\test_results.log", "UTF-8")
ExitApp(0)
