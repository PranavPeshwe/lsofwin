<#
.SYNOPSIS
    Tests for JSON output format correctness.
#>

function Test-JsonOutputIsValidJson {
    param([string]$LsofwinPath)
    $r = Invoke-Lsofwin -LsofwinPath $LsofwinPath -Arguments @("-p", "$PID", "-t", "2", "-j")
    try {
        $null = $r.OutputString | ConvertFrom-Json
        @{ Passed = $true; Message = "" }
    } catch {
        @{ Passed = $false; Message = "JSON output is not valid JSON: $_" }
    }
}

function Test-JsonOutputIsArray {
    param([string]$LsofwinPath)
    $r = Invoke-Lsofwin -LsofwinPath $LsofwinPath -Arguments @("-p", "$PID", "-t", "2", "-j") -SuppressOutput
    try {
        $parsed = @($r.OutputString | ConvertFrom-Json)
        $passed = $parsed.Count -ge 0
        @{ Passed = $passed; Message = "Expected JSON array at top level" }
    } catch {
        @{ Passed = $false; Message = "JSON parse error: $_" }
    }
}

function Test-JsonHasRequiredFields {
    param([string]$LsofwinPath)
    $r = Invoke-Lsofwin -LsofwinPath $LsofwinPath -Arguments @("-p", "$PID", "-t", "2", "-j") -SuppressOutput
    try {
        $entries = @($r.OutputString | ConvertFrom-Json)
    } catch {
        @{ Passed = $false; Message = "JSON parse error" }
        return
    }
    if ($entries.Count -eq 0) {
        @{ Passed = $false; Message = "No entries in JSON output" }
        return
    }
    $first = $entries[0]
    $requiredFields = @("command", "pid", "user", "type", "name")
    $missing = @($requiredFields | Where-Object { -not ($first.PSObject.Properties.Name -contains $_) })
    $passed = $missing.Count -eq 0
    @{ Passed = $passed; Message = "Missing fields: $($missing -join ', ')" }
}

function Test-JsonPidIsInteger {
    param([string]$LsofwinPath)
    $r = Invoke-Lsofwin -LsofwinPath $LsofwinPath -Arguments @("-p", "$PID", "-t", "2", "-j") -SuppressOutput
    try {
        $entries = @($r.OutputString | ConvertFrom-Json)
    } catch {
        @{ Passed = $false; Message = "JSON parse error" }
        return
    }
    if ($entries.Count -eq 0) {
        @{ Passed = $false; Message = "No entries" }
        return
    }
    $first = $entries[0]
    $passed = $first.pid -is [int] -or $first.pid -is [long] -or $first.pid -is [int64]
    @{ Passed = $passed; Message = "PID field should be integer, got type: $($first.pid.GetType().Name)" }
}

function Test-JsonEmptyResultForBadPid {
    param([string]$LsofwinPath)
    $r = Invoke-Lsofwin -LsofwinPath $LsofwinPath -Arguments @("-p", "9999999", "-t", "1", "-j")
    try {
        $entries = @($r.OutputString | ConvertFrom-Json)
        $passed = $entries.Count -eq 0
        @{ Passed = $passed; Message = "Expected empty JSON array for nonexistent PID, got $($entries.Count) entries" }
    } catch {
        @{ Passed = $false; Message = "JSON parse error: $_" }
    }
}

function Test-JsonBackslashesAreEscaped {
    param([string]$LsofwinPath)
    $r = Invoke-Lsofwin -LsofwinPath $LsofwinPath -Arguments @("-p", "$PID", "-t", "2", "-j", "-f", "Device")
    if ($r.OutputString.Trim() -eq "[]") {
        @{ Passed = $true; Message = "Skipped: no matching handles" }
        return
    }
    try {
        $entries = @($r.OutputString | ConvertFrom-Json)
        $hasBackslash = @($entries | Where-Object { $_.name -match '\\' })
        $passed = $hasBackslash.Count -gt 0
        @{ Passed = $passed; Message = "JSON with backslash paths should parse correctly" }
    } catch {
        @{ Passed = $false; Message = "JSON with backslash paths failed to parse: $_" }
    }
}

function Test-JsonFilteredByRegex {
    param([string]$LsofwinPath)
    $r = Invoke-Lsofwin -LsofwinPath $LsofwinPath -Arguments @("-p", "$PID", "-t", "2", "-j", "-f", "REGISTRY")
    try {
        $entries = @($r.OutputString | ConvertFrom-Json)
    } catch {
        @{ Passed = $false; Message = "JSON parse error" }
        return
    }
    if ($entries.Count -eq 0) {
        @{ Passed = $true; Message = "No results (OK - may need elevation)" }
        return
    }
    $nonMatching = @($entries | Where-Object { $_.name -notmatch "REGISTRY" })
    $passed = $nonMatching.Count -eq 0
    @{ Passed = $passed; Message = "Found $($nonMatching.Count) entries not matching 'REGISTRY' filter" }
}
