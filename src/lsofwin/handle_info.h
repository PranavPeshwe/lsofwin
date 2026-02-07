#pragma once

#include <string>
#include <vector>
#include <cstdint>

namespace lsofwin {

struct HandleInfo {
    uint32_t    pid = 0;
    std::string process_name;
    std::string user;
    std::string handle_type;
    std::string object_name;
    uintptr_t   handle_value = 0;
};

struct FilterOptions {
    int          filter_pid = -1;        // -p: filter by PID (-1 = no filter)
    std::string  filter_process_name;    // -c: filter by process name substring
    std::string  filter_file_regex;      // -f: filter by file path regex
    int          timeout_seconds = 5;    // -t: timeout per operation in seconds
    bool         output_json = false;    // -j: output as JSON
    bool         show_help = false;      // -h: show help
};

using HandleList = std::vector<HandleInfo>;

} // namespace lsofwin
