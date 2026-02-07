#include "cli_parser.h"
#include <sstream>
#include <cstdlib>
#include <regex>

namespace lsofwin {

std::string get_help_text(const char* program_name) {
    std::ostringstream oss;
    oss << "lsofwin - List open files on Windows\n"
        << "\n"
        << "Usage: " << program_name << " [OPTIONS]\n"
        << "\n"
        << "Options:\n"
        << "  -p <pid>       Show only handles for the specified process ID\n"
        << "  -c <name>      Show only handles for processes matching name (substring)\n"
        << "  -f <regex>     Filter results by file path (regular expression)\n"
        << "  -t <seconds>   Timeout per handle query operation (default: 5)\n"
        << "  -j, --json     Output results in JSON format\n"
        << "  -h, --help     Show this help message\n"
        << "\n"
        << "Examples:\n"
        << "  " << program_name << "                  List all open file handles\n"
        << "  " << program_name << " -p 1234          List handles for PID 1234\n"
        << "  " << program_name << " -c notepad       List handles for notepad processes\n"
        << "  " << program_name << " -f \".*\\.txt\"     List handles matching .txt files\n"
        << "  " << program_name << " -j               Output all handles as JSON\n"
        << "  " << program_name << " -p 1234 -j       Handles for PID 1234 as JSON\n"
        << "  " << program_name << " -t 10            Use 10 second timeout\n"
        << "\n"
        << "Notes:\n"
        << "  Running as Administrator is recommended for full results.\n"
        << "  Without elevation, only handles accessible to the current user are shown.\n";
    return oss.str();
}

bool parse_args(int argc, const char* const* argv, FilterOptions& opts, std::string& error_msg) {
    opts = FilterOptions{};

    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];

        if (arg == "-h" || arg == "--help") {
            opts.show_help = true;
            return true;
        }
        else if (arg == "-j" || arg == "--json") {
            opts.output_json = true;
        }
        else if (arg == "-p") {
            if (i + 1 >= argc) {
                error_msg = "Option -p requires a PID argument";
                return false;
            }
            ++i;
            char* end = nullptr;
            long val = std::strtol(argv[i], &end, 10);
            if (end == argv[i] || *end != '\0' || val < 0) {
                error_msg = "Invalid PID: " + std::string(argv[i]);
                return false;
            }
            opts.filter_pid = static_cast<int>(val);
        }
        else if (arg == "-c") {
            if (i + 1 >= argc) {
                error_msg = "Option -c requires a process name argument";
                return false;
            }
            ++i;
            opts.filter_process_name = argv[i];
        }
        else if (arg == "-f") {
            if (i + 1 >= argc) {
                error_msg = "Option -f requires a regex argument";
                return false;
            }
            ++i;
            opts.filter_file_regex = argv[i];
            // Validate regex
            try {
                std::regex test_re(opts.filter_file_regex, std::regex::icase);
                (void)test_re;
            }
            catch (const std::regex_error& e) {
                error_msg = "Invalid regex: " + std::string(e.what());
                return false;
            }
        }
        else if (arg == "-t") {
            if (i + 1 >= argc) {
                error_msg = "Option -t requires a timeout value in seconds";
                return false;
            }
            ++i;
            char* end = nullptr;
            long val = std::strtol(argv[i], &end, 10);
            if (end == argv[i] || *end != '\0' || val <= 0) {
                error_msg = "Invalid timeout: " + std::string(argv[i]);
                return false;
            }
            opts.timeout_seconds = static_cast<int>(val);
        }
        else {
            error_msg = "Unknown option: " + arg;
            return false;
        }
    }

    return true;
}

} // namespace lsofwin
