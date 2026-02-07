#include "output_formatter.h"
#include <sstream>
#include <iomanip>
#include <algorithm>

namespace lsofwin {

std::string format_table(const HandleList& handles) {
    if (handles.empty()) {
        return "No open handles found.\n";
    }

    // Calculate column widths
    size_t w_cmd = 7, w_pid = 3, w_user = 4, w_type = 4, w_name = 4;
    for (const auto& h : handles) {
        w_cmd  = (std::max)(w_cmd,  h.process_name.size());
        w_pid  = (std::max)(w_pid,  std::to_string(h.pid).size());
        w_user = (std::max)(w_user, h.user.size());
        w_type = (std::max)(w_type, h.handle_type.size());
        w_name = (std::max)(w_name, h.object_name.size());
    }

    // Cap widths for readability
    w_cmd  = (std::min)(w_cmd,  (size_t)25);
    w_user = (std::min)(w_user, (size_t)30);
    w_type = (std::min)(w_type, (size_t)20);

    std::ostringstream oss;

    // Header
    oss << std::left
        << std::setw(static_cast<int>(w_cmd + 2))  << "COMMAND"
        << std::setw(static_cast<int>(w_pid + 2))  << "PID"
        << std::setw(static_cast<int>(w_user + 2)) << "USER"
        << std::setw(static_cast<int>(w_type + 2)) << "TYPE"
        << "NAME\n";

    // Rows
    for (const auto& h : handles) {
        std::string cmd = h.process_name;
        if (cmd.size() > w_cmd) cmd = cmd.substr(0, w_cmd - 1) + "~";

        std::string user = h.user;
        if (user.size() > w_user) user = user.substr(0, w_user - 1) + "~";

        std::string type = h.handle_type;
        if (type.size() > w_type) type = type.substr(0, w_type - 1) + "~";

        oss << std::left
            << std::setw(static_cast<int>(w_cmd + 2))  << cmd
            << std::setw(static_cast<int>(w_pid + 2))  << h.pid
            << std::setw(static_cast<int>(w_user + 2)) << user
            << std::setw(static_cast<int>(w_type + 2)) << type
            << h.object_name << "\n";
    }

    return oss.str();
}

namespace {

std::string json_escape(const std::string& s) {
    std::string result;
    result.reserve(s.size() + 8);
    for (char c : s) {
        switch (c) {
        case '"':  result += "\\\""; break;
        case '\\': result += "\\\\"; break;
        case '\b': result += "\\b";  break;
        case '\f': result += "\\f";  break;
        case '\n': result += "\\n";  break;
        case '\r': result += "\\r";  break;
        case '\t': result += "\\t";  break;
        default:
            if (static_cast<unsigned char>(c) < 0x20) {
                char buf[8];
                snprintf(buf, sizeof(buf), "\\u%04x", static_cast<unsigned char>(c));
                result += buf;
            }
            else {
                result += c;
            }
            break;
        }
    }
    return result;
}

} // anonymous namespace

std::string format_json(const HandleList& handles) {
    std::ostringstream oss;
    oss << "[\n";

    for (size_t i = 0; i < handles.size(); ++i) {
        const auto& h = handles[i];
        oss << "  {\n"
            << "    \"command\": \"" << json_escape(h.process_name) << "\",\n"
            << "    \"pid\": " << h.pid << ",\n"
            << "    \"user\": \"" << json_escape(h.user) << "\",\n"
            << "    \"type\": \"" << json_escape(h.handle_type) << "\",\n"
            << "    \"name\": \"" << json_escape(h.object_name) << "\"\n"
            << "  }";
        if (i + 1 < handles.size()) oss << ",";
        oss << "\n";
    }

    oss << "]\n";
    return oss.str();
}

std::string format_output(const HandleList& handles, const FilterOptions& opts) {
    if (opts.output_json) {
        return format_json(handles);
    }
    return format_table(handles);
}

} // namespace lsofwin
