#pragma once

#include "handle_info.h"
#include <string>
#include <vector>

namespace lsofwin {

// Parse command-line arguments into FilterOptions.
// Returns true on success, false on error (error_msg will be set).
bool parse_args(int argc, const char* const* argv, FilterOptions& opts, std::string& error_msg);

// Returns the help/usage text.
std::string get_help_text(const char* program_name);

} // namespace lsofwin
