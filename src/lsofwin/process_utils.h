#pragma once

#include <string>
#include <cstdint>

namespace lsofwin {

// Get the executable name for a given PID. Returns empty string on failure.
std::string get_process_name(uint32_t pid);

// Get the owner (DOMAIN\User) for a given PID. Returns empty string on failure.
std::string get_process_user(uint32_t pid);

// Check if the current process is running with Administrator privileges.
bool is_elevated();

} // namespace lsofwin
