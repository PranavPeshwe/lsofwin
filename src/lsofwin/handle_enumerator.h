#pragma once

#include "handle_info.h"
#include <string>

namespace lsofwin {

// Enumerate open file handles system-wide, applying the given filters.
// Returns a list of HandleInfo. timeout_ms is per-handle query timeout.
HandleList enumerate_handles(const FilterOptions& opts);

// Returns a human-readable privilege warning if not elevated, empty otherwise.
std::string get_privilege_warning();

} // namespace lsofwin
