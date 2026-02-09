#include "cli_parser.h"
#include "console_color.h"
#include <sstream>
#include <cstdlib>
#include <regex>

namespace lsofwin {

std::string get_help_text(const char* program_name) {
    const char* B  = color::c(color::BOLD);
    const char* BC = color::c(color::BOLD_CYAN);
    const char* BG = color::c(color::BOLD_GREEN);
    const char* BY = color::c(color::BOLD_YELLOW);
    const char* DM = color::c(color::DIM);
    const char* R  = color::c(color::RESET);

    std::ostringstream oss;
    oss << BC << "lsofwin" << R << " - List open files on Windows\n"
        << "\n"
        << B << "USAGE:" << R << "\n"
        << "  " << program_name << " [OPTIONS]\n"
        << "\n"
        << B << "OPTIONS:" << R << "\n"
        << "  " << BG << "-p" << R << " <pid>       Show only handles for the specified process ID\n"
        << "  " << BG << "-c" << R << " <name>      Show only handles for processes matching name " << DM << "(case-insensitive substring)" << R << "\n"
        << "  " << BG << "-f" << R << " <regex>     Filter results by file/object path " << DM << "(regular expression, case-insensitive)" << R << "\n"
        << "  " << BG << "-t" << R << " <seconds>   Timeout per handle query operation " << DM << "(default: 5)" << R << "\n"
        << "  " << BG << "-j" << R << ", " << BG << "--json" << R << "     Output results in JSON format\n"
        << "  " << BG << "-v" << R << ", " << BG << "--version" << R << "  Show version information\n"
        << "  " << BG << "-h" << R << ", " << BG << "--help" << R << "     Show this help message\n"
        << "\n"
        << B << "EXAMPLES:" << R << "\n"
        << "\n"
        << "  " << BY << "# List all open handles (run as Admin for full results)" << R << "\n"
        << "  " << program_name << "\n"
        << "\n"
        << "  " << BY << "# List handles for a specific process by PID" << R << "\n"
        << "  " << program_name << " -p 1234\n"
        << "\n"
        << "  " << BY << "# Find handles opened by notepad" << R << "\n"
        << "  " << program_name << " -c notepad\n"
        << "\n"
        << "  " << BY << "# Find which process has a specific file open" << R << "\n"
        << "  " << program_name << " -f \"myfile\\.docx\"\n"
        << "\n"
        << "  " << BY << "# Find all open .txt files" << R << "\n"
        << "  " << program_name << " -f \"\\.txt$\"\n"
        << "\n"
        << "  " << BY << "# Find all open .log or .txt files" << R << "\n"
        << "  " << program_name << " -f \"\\.(log|txt)$\"\n"
        << "\n"
        << "  " << BY << "# Find files open under a specific directory" << R << "\n"
        << "  " << program_name << " -f \"C:\\\\Users\\\\John\"\n"
        << "\n"
        << "  " << BY << "# Combine: .dll files opened by explorer" << R << "\n"
        << "  " << program_name << " -c explorer -f \"\\.dll\"\n"
        << "\n"
        << "  " << BY << "# Combine: registry keys for a specific PID" << R << "\n"
        << "  " << program_name << " -p 1234 -f \"REGISTRY\"\n"
        << "\n"
        << "  " << BY << "# JSON output for scripting and piping" << R << "\n"
        << "  " << program_name << " -p 1234 -j\n"
        << "\n"
        << "  " << BY << "# JSON output piped to PowerShell for processing" << R << "\n"
        << "  " << program_name << " -c chrome -j | ConvertFrom-Json | Where-Object { $_.type -eq 'File' }\n"
        << "\n"
        << "  " << BY << "# Use a longer timeout on busy systems" << R << "\n"
        << "  " << program_name << " -t 15\n"
        << "\n"
        << "  " << BY << "# Quick scan with short timeout" << R << "\n"
        << "  " << program_name << " -p 1234 -t 1\n"
        << "\n"
        << B << "NOTES:" << R << "\n"
        << "  Running as " << BC << "Administrator" << R << " is recommended for full results.\n"
        << "  Without elevation, only handles accessible to the current user are shown.\n"
        << "  The " << BG << "-f" << R << " regex is matched case-insensitively against the full object path.\n"
        << "  Use " << BG << "-t" << R << " to prevent hangs on pipe/device handles (default: 5 seconds).\n";
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
        else if (arg == "-v" || arg == "--version") {
            opts.show_version = true;
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
