; ============================================================================
; IME state — Microsoft Pinyin (and other IMM-based IMEs)
; ============================================================================

; Get raw IME conversion mode (full int) for the given top-level window.
; Returns -1 when unavailable (no IME / sandboxed window / timeout).
GetIMEModeRaw(hwnd) {
    if !hwnd
        return -1
    hIME := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", hwnd, "Ptr")
    if !hIME
        return -1
    ; WM_IME_CONTROL = 0x283 ; IMC_GETCONVERSIONMODE = 0x001
    mode := ""
    try mode := SendMessage(0x283, 0x001, 0, , "ahk_id " . hIME, , , , 200)
    if (mode = "" || mode = -1)
        return -1
    return mode + 0
}

; Convenience: Chinese (1) / English (0) / unavailable (-1).
GetIMEMode(hwnd) {
    raw := GetIMEModeRaw(hwnd)
    if (raw = -1)
        return -1
    return (raw & 1) ? 1 : 0
}

; Force the IME to a given raw conversion mode. Returns true on success.
SetIMEModeRaw(hwnd, mode) {
    if (!hwnd || mode = "" || mode = -1)
        return false
    hIME := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", hwnd, "Ptr")
    if !hIME
        return false
    ; WM_IME_CONTROL = 0x283 ; IMC_SETCONVERSIONMODE = 0x002
    try {
        SendMessage(0x283, 0x002, mode, , "ahk_id " . hIME, , , , 300)
        return true
    } catch {
        return false
    }
}
