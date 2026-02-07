#pragma once

#include "handle_info.h"
#include <string>

namespace lsofwin {

// Format handles as a human-readable table.
std::string format_table(const HandleList& handles);

// Format handles as a JSON array.
std::string format_json(const HandleList& handles);

// Format output based on FilterOptions (delegates to format_table or format_json).
std::string format_output(const HandleList& handles, const FilterOptions& opts);

} // namespace lsofwin
