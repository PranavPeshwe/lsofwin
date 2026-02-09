# lsofwin

A Windows equivalent of the Linux `lsof` (list open files) utility. Enumerates open file handles across processes using the Windows NT API.

## Features

- **List open file handles** system-wide or per-process
- **Filter by PID** (`-p`) — show handles for a specific process
- **Filter by process name** (`-c`) — match processes by name (case-insensitive substring)
- **Filter by file path regex** (`-f`) — filter handles using regular expressions
- **Configurable timeout** (`-t`) — per-operation timeout to avoid hangs on pipes/devices (default: 5s)
- **JSON output** (`-j` / `--json`) — machine-readable JSON output for scripting
- **Graceful privilege degradation** — works without Admin, but shows more with elevation

## Usage

```
lsofwin [OPTIONS]

Options:
  -p <pid>       Show only handles for the specified process ID
  -c <name>      Show only handles for processes matching name (substring)
  -f <regex>     Filter results by file path (regular expression)
  -t <seconds>   Timeout per handle query operation (default: 5)
  -j, --json     Output results in JSON format
  -v, --version  Show version information
  -h, --help     Show this help message
```

## Examples

List all open file handles (requires Administrator for full results):
```
lsofwin
```

List handles for a specific process:
```
lsofwin -p 1234
```

Find which process has a file open:
```
lsofwin -f "myfile\.docx"
```

List all `.log` files opened by any process:
```
lsofwin -f ".*\.log"
```

Filter by process name:
```
lsofwin -c notepad
```

Combine filters — all `.dll` files opened by explorer:
```
lsofwin -c explorer -f "dll"
```

JSON output for scripting:
```
lsofwin -p 1234 -j
```

Use a longer timeout for systems with many handles:
```
lsofwin -t 10
```

## Output Format

### Table (default)

```
COMMAND       PID    USER                  TYPE  NAME
explorer.exe  11228  DOMAIN\Username       File  C:\Windows\System32\en-US\shell32.dll.mui
notepad.exe   5432   DOMAIN\Username       File  C:\Users\Username\document.txt
```

### JSON (`-j`)

```json
[
  {
    "command": "explorer.exe",
    "pid": 11228,
    "user": "DOMAIN\\Username",
    "type": "File",
    "name": "C:\\Windows\\System32\\en-US\\shell32.dll.mui"
  }
]
```

## Building

### Requirements

- Visual Studio 2022 (v143 toolset)
- Windows SDK 10.0
- C++17

### Build from Command Line

```
msbuild lsofwin.sln /p:Configuration=Release /p:Platform=x64
```

The output binary is at `build\Release\lsofwin.exe`.

### Build from Visual Studio

Open `lsofwin.sln` in Visual Studio 2022 and build the `Release|x64` configuration.

## Architecture

```
src/lsofwin/
├── main.cpp               Entry point, CLI orchestration
├── cli_parser.h/.cpp       Command-line argument parsing
├── handle_info.h           Core data structures (HandleInfo, FilterOptions)
├── handle_enumerator.h/.cpp  Handle enumeration via NT API
├── process_utils.h/.cpp    Process name/user lookup
└── output_formatter.h/.cpp Table and JSON output formatting
```

### How It Works

1. **Handle Enumeration**: Uses `NtQuerySystemInformation(SystemHandleInformation)` to get all open handles system-wide
2. **Handle Resolution**: Duplicates each handle into the current process and uses `NtQueryObject` to resolve the object name and type
3. **Timeout Protection**: `NtQueryObject` can hang on certain handle types (named pipes, ALPC ports). A worker thread with `WaitForSingleObject` timeout prevents blocking
4. **Path Normalization**: NT device paths (e.g., `\Device\HarddiskVolume3\...`) are converted to DOS paths (e.g., `C:\...`) using `QueryDosDevice`
5. **Process Info Caching**: Process names and users are cached to avoid repeated lookups for the same PID

## Privileges

- **Administrator**: Full access to all process handles system-wide
- **Standard user**: Can only access handles for processes owned by the current user. A warning is displayed on stderr

## Linked Libraries

- `ntdll.lib` — NT API functions (`NtQuerySystemInformation`, `NtQueryObject`)
- `advapi32.lib` — Security functions (`OpenProcessToken`, `LookupAccountSid`)
- `psapi.lib` — Process information (`GetModuleBaseName`)

## License

This project is provided as-is for educational and utility purposes.
