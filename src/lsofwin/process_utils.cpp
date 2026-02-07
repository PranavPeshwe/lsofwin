#include "process_utils.h"

#include <Windows.h>
#include <Psapi.h>
#include <sddl.h>
#include <memory>

#pragma comment(lib, "advapi32.lib")
#pragma comment(lib, "psapi.lib")

namespace lsofwin {

std::string get_process_name(uint32_t pid) {
    if (pid == 0) return "[System Idle Process]";
    if (pid == 4) return "System";

    HANDLE hProcess = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_VM_READ, FALSE, pid);
    if (!hProcess) return "";

    char name[MAX_PATH] = {};
    DWORD size = MAX_PATH;

    // Try QueryFullProcessImageNameA first (works without VM_READ)
    if (QueryFullProcessImageNameA(hProcess, 0, name, &size)) {
        CloseHandle(hProcess);
        std::string full_path(name);
        auto pos = full_path.find_last_of("\\/");
        return (pos != std::string::npos) ? full_path.substr(pos + 1) : full_path;
    }

    // Fallback to GetModuleBaseNameA
    if (GetModuleBaseNameA(hProcess, nullptr, name, MAX_PATH) > 0) {
        CloseHandle(hProcess);
        return std::string(name);
    }

    CloseHandle(hProcess);
    return "";
}

std::string get_process_user(uint32_t pid) {
    if (pid == 0 || pid == 4) return "SYSTEM";

    HANDLE hProcess = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
    if (!hProcess) return "";

    HANDLE hToken = nullptr;
    if (!OpenProcessToken(hProcess, TOKEN_QUERY, &hToken)) {
        CloseHandle(hProcess);
        return "";
    }

    DWORD token_size = 0;
    GetTokenInformation(hToken, TokenUser, nullptr, 0, &token_size);
    if (token_size == 0) {
        CloseHandle(hToken);
        CloseHandle(hProcess);
        return "";
    }

    auto buffer = std::make_unique<char[]>(token_size);
    if (!GetTokenInformation(hToken, TokenUser, buffer.get(), token_size, &token_size)) {
        CloseHandle(hToken);
        CloseHandle(hProcess);
        return "";
    }

    auto* token_user = reinterpret_cast<TOKEN_USER*>(buffer.get());
    char user_name[256] = {};
    char domain_name[256] = {};
    DWORD user_size = 256, domain_size = 256;
    SID_NAME_USE sid_type;

    if (!LookupAccountSidA(nullptr, token_user->User.Sid,
        user_name, &user_size, domain_name, &domain_size, &sid_type)) {
        CloseHandle(hToken);
        CloseHandle(hProcess);
        return "";
    }

    CloseHandle(hToken);
    CloseHandle(hProcess);

    std::string result;
    if (domain_name[0] != '\0') {
        result = std::string(domain_name) + "\\" + user_name;
    }
    else {
        result = user_name;
    }
    return result;
}

bool is_elevated() {
    HANDLE hToken = nullptr;
    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &hToken)) {
        return false;
    }

    TOKEN_ELEVATION elevation = {};
    DWORD size = sizeof(elevation);
    BOOL result = GetTokenInformation(hToken, TokenElevation, &elevation, sizeof(elevation), &size);
    CloseHandle(hToken);

    return result && elevation.TokenIsElevated;
}

} // namespace lsofwin
