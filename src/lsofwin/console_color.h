#pragma once

#include <string>

#ifndef NOMINMAX
#define NOMINMAX
#endif
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <Windows.h>

namespace lsofwin {
namespace color {

// ANSI color codes
inline constexpr const char* RESET   = "\033[0m";
inline constexpr const char* BOLD    = "\033[1m";
inline constexpr const char* RED     = "\033[31m";
inline constexpr const char* GREEN   = "\033[32m";
inline constexpr const char* YELLOW  = "\033[33m";
inline constexpr const char* CYAN    = "\033[36m";
inline constexpr const char* WHITE   = "\033[37m";
inline constexpr const char* BOLD_RED    = "\033[1;31m";
inline constexpr const char* BOLD_GREEN  = "\033[1;32m";
inline constexpr const char* BOLD_YELLOW = "\033[1;33m";
inline constexpr const char* BOLD_CYAN   = "\033[1;36m";
inline constexpr const char* BOLD_WHITE  = "\033[1;37m";
inline constexpr const char* DIM     = "\033[2m";

// Enable ANSI/VT100 escape sequences on Windows console.
// Call once at startup. Returns true if color is supported.
inline bool enable_virtual_terminal() {
    HANDLE hOut = GetStdHandle(STD_OUTPUT_HANDLE);
    HANDLE hErr = GetStdHandle(STD_ERROR_HANDLE);
    if (hOut == INVALID_HANDLE_VALUE || hErr == INVALID_HANDLE_VALUE) return false;

    DWORD mode = 0;
    if (!GetConsoleMode(hOut, &mode)) return false;
    mode |= ENABLE_VIRTUAL_TERMINAL_PROCESSING;
    if (!SetConsoleMode(hOut, mode)) return false;

    if (GetConsoleMode(hErr, &mode)) {
        mode |= ENABLE_VIRTUAL_TERMINAL_PROCESSING;
        SetConsoleMode(hErr, mode);
    }
    return true;
}

// Check if stdout is a real console (not redirected to file/pipe)
inline bool is_console_output() {
    HANDLE hOut = GetStdHandle(STD_OUTPUT_HANDLE);
    DWORD mode = 0;
    return GetConsoleMode(hOut, &mode) != 0;
}

// Global flag set by init — when false, all color functions return empty strings
inline bool g_color_enabled = false;

inline void init() {
    if (is_console_output()) {
        g_color_enabled = enable_virtual_terminal();
    }
}

// Return color code only if color is enabled
inline const char* c(const char* code) {
    return g_color_enabled ? code : "";
}

} // namespace color
} // namespace lsofwin
