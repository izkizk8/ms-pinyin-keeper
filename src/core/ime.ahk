; ============================================================================
; IME state — Microsoft Pinyin (and other IMM-based IMEs)
; Returns: 1 = Chinese (native), 0 = English (alphanumeric), -1 = unavailable
; ============================================================================

GetIMEMode(hwnd) {
    if !hwnd
        return -1
    hIME := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", hwnd, "Ptr")
    if !hIME
        return -1
    ; WM_IME_CONTROL = 0x283 ; IMC_GETCONVERSIONMODE = 0x001
    mode := -1
    try mode := SendMessage(0x283, 0x001, 0, , "ahk_id " . hIME, , , , 200)
    if (mode = "" || mode = -1)
        return -1
    ; Bit 0 (IME_CMODE_NATIVE) → Chinese mode
    return (mode & 1) ? 1 : 0
}
