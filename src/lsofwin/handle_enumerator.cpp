#include "handle_enumerator.h"
#include "process_utils.h"
#include "console_color.h"

#include <Windows.h>
#include <winternl.h>
#include <algorithm>
#include <unordered_map>
#include <regex>
#include <mutex>

#pragma comment(lib, "ntdll.lib")

// NT API types not in standard headers
extern "C" {
    typedef struct _SYSTEM_HANDLE_TABLE_ENTRY_INFO_EX {
        PVOID      Object;
        ULONG_PTR  UniqueProcessId;
        ULONG_PTR  HandleValue;
        ULONG      GrantedAccess;
        USHORT     CreatorBackTraceIndex;
        USHORT     ObjectTypeIndex;
        ULONG      HandleAttributes;
        ULONG      Reserved;
    } SYSTEM_HANDLE_TABLE_ENTRY_INFO_EX;

    typedef struct _SYSTEM_HANDLE_INFORMATION_EX {
        ULONG_PTR NumberOfHandles;
        ULONG_PTR Reserved;
        SYSTEM_HANDLE_TABLE_ENTRY_INFO_EX Handles[1];
    } SYSTEM_HANDLE_INFORMATION_EX;
}

namespace {

constexpr ULONG SystemExtendedHandleInformationClass = 64;
constexpr ULONG ObjectNameInformationClass = 1;
constexpr ULONG ObjectTypeInformationClass = 2;

struct ObjectNameInfo {
    UNICODE_STRING Name;
    WCHAR NameBuffer[1];
};

struct ObjectTypeInfo {
    UNICODE_STRING TypeName;
    ULONG Reserved[22];
};

// Thread-safe cache for process info
struct ProcessCacheEntry {
    std::string name;
    std::string user;
};

std::string wide_to_narrow(const WCHAR* wstr, int len) {
    if (!wstr || len <= 0) return "";
    int needed = WideCharToMultiByte(CP_UTF8, 0, wstr, len, nullptr, 0, nullptr, nullptr);
    if (needed <= 0) return "";
    std::string result(needed, '\0');
    WideCharToMultiByte(CP_UTF8, 0, wstr, len, &result[0], needed, nullptr, nullptr);
    return result;
}

// Query object name with timeout to avoid hangs on pipes/devices
struct QueryThreadData {
    HANDLE handle;
    PVOID buffer;
    ULONG buffer_size;
    NTSTATUS status;
    ULONG return_length;
};

DWORD WINAPI query_object_name_thread(LPVOID param) {
    auto* data = static_cast<QueryThreadData*>(param);
    data->status = NtQueryObject(data->handle, (OBJECT_INFORMATION_CLASS)ObjectNameInformationClass,
        data->buffer, data->buffer_size, &data->return_length);
    return 0;
}

bool query_object_name_with_timeout(HANDLE handle, PVOID buffer, ULONG buffer_size,
    NTSTATUS& status, DWORD timeout_ms) {
    QueryThreadData data = { handle, buffer, buffer_size, 0, 0 };

    HANDLE hThread = CreateThread(nullptr, 0, query_object_name_thread, &data, 0, nullptr);
    if (!hThread) return false;

    DWORD wait_result = WaitForSingleObject(hThread, timeout_ms);
    if (wait_result == WAIT_TIMEOUT) {
        // Thread is stuck — terminate it to avoid hanging
        TerminateThread(hThread, 1);
        CloseHandle(hThread);
        return false;
    }

    CloseHandle(hThread);
    status = data.status;
    return true;
}

// Convert NT device path to DOS path
std::string normalize_path(const std::string& nt_path) {
    // Map \Device\HarddiskVolumeN to drive letters
    char drives[512];
    if (GetLogicalDriveStringsA(sizeof(drives) - 1, drives) == 0) return nt_path;

    for (const char* drive = drives; *drive; drive += strlen(drive) + 1) {
        char device_name[3] = { drive[0], drive[1], '\0' }; // "C:"
        char target[MAX_PATH] = {};
        if (QueryDosDeviceA(device_name, target, MAX_PATH) > 0) {
            std::string target_str(target);
            if (nt_path.compare(0, target_str.size(), target_str) == 0) {
                return std::string(device_name) + nt_path.substr(target_str.size());
            }
        }
    }
    return nt_path;
}

} // anonymous namespace

namespace lsofwin {

std::string get_privilege_warning() {
    if (!is_elevated()) {
        std::string w;
        w += color::c(color::BOLD_YELLOW);
        w += "WARNING:";
        w += color::c(color::RESET);
        w += color::c(color::YELLOW);
        w += " Not running as Administrator. Results may be incomplete.\n";
        w += "         Run from an elevated command prompt for full results.\n";
        w += color::c(color::RESET);
        return w;
    }
    return "";
}

HandleList enumerate_handles(const FilterOptions& opts) {
    HandleList results;
    DWORD timeout_ms = static_cast<DWORD>(opts.timeout_seconds) * 1000;

    // Allocate buffer for system handle information
    ULONG buffer_size = 1024 * 1024; // Start with 1 MB
    auto buffer = std::make_unique<char[]>(buffer_size);
    NTSTATUS status;
    ULONG return_length = 0;

    // Grow buffer until it fits
    while (true) {
        status = NtQuerySystemInformation(
            (SYSTEM_INFORMATION_CLASS)SystemExtendedHandleInformationClass,
            buffer.get(), buffer_size, &return_length);

        if (status == (NTSTATUS)0xC0000004L) { // STATUS_INFO_LENGTH_MISMATCH
            buffer_size = return_length + 65536;
            buffer = std::make_unique<char[]>(buffer_size);
            continue;
        }
        break;
    }

    if (status != 0) return results;

    auto* handle_info = reinterpret_cast<SYSTEM_HANDLE_INFORMATION_EX*>(buffer.get());

    // Build process cache
    std::unordered_map<uint32_t, ProcessCacheEntry> proc_cache;

    // Pre-compile regex if specified
    std::regex file_regex;
    bool use_regex = !opts.filter_file_regex.empty();
    if (use_regex) {
        file_regex = std::regex(opts.filter_file_regex, std::regex::icase);
    }

    // Buffer for object queries
    const ULONG obj_buf_size = 2048;
    auto obj_buffer = std::make_unique<char[]>(obj_buf_size);

    for (ULONG_PTR i = 0; i < handle_info->NumberOfHandles; ++i) {
        auto& entry = handle_info->Handles[i];
        uint32_t pid = static_cast<uint32_t>(entry.UniqueProcessId);

        // Apply PID filter early
        if (opts.filter_pid >= 0 && static_cast<int>(pid) != opts.filter_pid) {
            continue;
        }

        // Lookup/cache process info
        auto cache_it = proc_cache.find(pid);
        if (cache_it == proc_cache.end()) {
            ProcessCacheEntry pce;
            pce.name = get_process_name(pid);
            pce.user = get_process_user(pid);
            proc_cache[pid] = std::move(pce);
            cache_it = proc_cache.find(pid);
        }

        // Apply process name filter
        if (!opts.filter_process_name.empty()) {
            const auto& pname = cache_it->second.name;
            // Case-insensitive substring match
            std::string pname_lower = pname;
            std::string filter_lower = opts.filter_process_name;
            std::transform(pname_lower.begin(), pname_lower.end(), pname_lower.begin(),
                [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
            std::transform(filter_lower.begin(), filter_lower.end(), filter_lower.begin(),
                [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
            if (pname_lower.find(filter_lower) == std::string::npos) {
                continue;
            }
        }

        // Duplicate handle into our process to query it
        HANDLE target_process = OpenProcess(PROCESS_DUP_HANDLE, FALSE, pid);
        if (!target_process) continue;

        HANDLE dup_handle = nullptr;
        if (!DuplicateHandle(target_process, (HANDLE)(uintptr_t)entry.HandleValue,
            GetCurrentProcess(), &dup_handle, 0, FALSE, DUPLICATE_SAME_ACCESS)) {
            CloseHandle(target_process);
            continue;
        }
        CloseHandle(target_process);

        // Query object type
        std::string type_name;
        memset(obj_buffer.get(), 0, obj_buf_size);
        ULONG obj_return_len = 0;
        status = NtQueryObject(dup_handle, (OBJECT_INFORMATION_CLASS)ObjectTypeInformationClass,
            obj_buffer.get(), obj_buf_size, &obj_return_len);

        if (status == 0) {
            auto* type_info = reinterpret_cast<ObjectTypeInfo*>(obj_buffer.get());
            type_name = wide_to_narrow(type_info->TypeName.Buffer,
                type_info->TypeName.Length / sizeof(WCHAR));
        }

        // Query object name with timeout
        std::string object_name;
        memset(obj_buffer.get(), 0, obj_buf_size);
        NTSTATUS name_status;
        if (query_object_name_with_timeout(dup_handle, obj_buffer.get(), obj_buf_size,
            name_status, timeout_ms)) {
            if (name_status == 0) {
                auto* name_info = reinterpret_cast<ObjectNameInfo*>(obj_buffer.get());
                if (name_info->Name.Length > 0) {
                    object_name = wide_to_narrow(name_info->Name.Buffer,
                        name_info->Name.Length / sizeof(WCHAR));
                    object_name = normalize_path(object_name);
                }
            }
        }

        CloseHandle(dup_handle);

        // Apply file regex filter
        if (use_regex && !object_name.empty()) {
            if (!std::regex_search(object_name, file_regex)) {
                continue;
            }
        }
        else if (use_regex && object_name.empty()) {
            continue; // regex specified but no name to match
        }

        HandleInfo hi;
        hi.pid = pid;
        hi.process_name = cache_it->second.name;
        hi.user = cache_it->second.user;
        hi.handle_type = type_name;
        hi.object_name = object_name;
        hi.handle_value = entry.HandleValue;

        results.push_back(std::move(hi));
    }

    return results;
}

} // namespace lsofwin
