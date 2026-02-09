#include "cli_parser.h"
#include "handle_enumerator.h"
#include "output_formatter.h"
#include "process_utils.h"
#include "console_color.h"
#include "version.h"

#include <iostream>
#include <string>

int main(int argc, char* argv[]) {
    lsofwin::color::init();

    lsofwin::FilterOptions opts;
    std::string error_msg;

    if (!lsofwin::parse_args(argc, argv, opts, error_msg)) {
        std::cerr << lsofwin::color::c(lsofwin::color::BOLD_RED)
                  << "Error: " << error_msg
                  << lsofwin::color::c(lsofwin::color::RESET) << "\n\n";
        std::cerr << lsofwin::get_help_text(argv[0]);
        return 1;
    }

    if (opts.show_version) {
        std::cout << "lsofwin " << LSOFWIN_VERSION << "\n";
        return 0;
    }

    if (opts.show_help) {
        std::cout << lsofwin::get_help_text(argv[0]);
        return 0;
    }

    // Privilege warning
    std::string warning = lsofwin::get_privilege_warning();
    if (!warning.empty() && !opts.output_json) {
        std::cerr << warning << "\n";
    }

    // Enumerate handles
    lsofwin::HandleList handles = lsofwin::enumerate_handles(opts);

    // Output results
    std::cout << lsofwin::format_output(handles, opts);

    return 0;
}
