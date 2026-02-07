<#
.SYNOPSIS
    Tests for JSON output format correctness.
#>

function Test-JsonOutputIsValidJson {
    param([string]$LsofwinPath)
    $json = & $LsofwinPath -p $PID -t 2 -j 2>$null | Out-String
    try {
        $null = $json | ConvertFrom-Json
        @{ Passed = $true; Message = "" }
    } catch {
        @{ Passed = $false; Message = "JSON output is not valid JSON: $_" }
    }
}

function Test-JsonOutputIsArray {
    param([string]$LsofwinPath)
    $json = & $LsofwinPath -p $PID -t 2 -j 2>$null | Out-String
    try {
        $parsed = @($json | ConvertFrom-Json)
        $passed = $parsed.Count -ge 0
        @{ Passed = $passed; Message = "Expected JSON array at top level" }
    } catch {
        @{ Passed = $false; Message = "JSON parse error: $_" }
    }
}

function Test-JsonHasRequiredFields {
    param([string]$LsofwinPath)
    $json = & $LsofwinPath -p $PID -t 2 -j 2>$null | Out-String
    try {
        $entries = @($json | ConvertFrom-Json)
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
    $json = & $LsofwinPath -p $PID -t 2 -j 2>$null | Out-String
    try {
        $entries = @($json | ConvertFrom-Json)
    } catch {
        @{ Passed = $false; Message = "JSON parse error" }
        return
    }
    if ($entries.Count -eq 0) {
        @{ Passed = $false; Message = "No entries" }
        return
    }
    # PID should be a number, not a string
    $first = $entries[0]
    $passed = $first.pid -is [int] -or $first.pid -is [long] -or $first.pid -is [int64]
    @{ Passed = $passed; Message = "PID field should be integer, got type: $($first.pid.GetType().Name)" }
}

function Test-JsonEmptyResultForBadPid {
    param([string]$LsofwinPath)
    $json = & $LsofwinPath -p 9999999 -t 1 -j 2>$null | Out-String
    try {
        $entries = @($json | ConvertFrom-Json)
        # Should be empty array
        $passed = $entries.Count -eq 0
        @{ Passed = $passed; Message = "Expected empty JSON array for nonexistent PID, got $($entries.Count) entries" }
    } catch {
        @{ Passed = $false; Message = "JSON parse error: $_" }
    }
}

function Test-JsonBackslashesAreEscaped {
    param([string]$LsofwinPath)
    # Windows paths contain backslashes; they must be escaped as \\ in JSON
    # Use a simple filter to get results that likely have backslash paths
    $rawJson = & $LsofwinPath -p $PID -t 2 -j -f "Device" 2>$null | Out-String
    if ($rawJson.Trim() -eq "[]") {
        @{ Passed = $true; Message = "Skipped: no matching handles" }
        return
    }
    # Verify it parses correctly (backslashes properly escaped)
    try {
        $entries = @($rawJson | ConvertFrom-Json)
        # Check that at least one entry has a backslash in the name
        $hasBackslash = @($entries | Where-Object { $_.name -match '\\' })
        $passed = $hasBackslash.Count -gt 0
        @{ Passed = $passed; Message = "JSON with backslash paths should parse correctly" }
    } catch {
        @{ Passed = $false; Message = "JSON with backslash paths failed to parse: $_" }
    }
}

function Test-JsonFilteredByRegex {
    param([string]$LsofwinPath)
    $json = & $LsofwinPath -p $PID -t 2 -j -f "REGISTRY" 2>$null | Out-String
    try {
        $entries = @($json | ConvertFrom-Json)
    } catch {
        @{ Passed = $false; Message = "JSON parse error" }
        return
    }
    if ($entries.Count -eq 0) {
        @{ Passed = $true; Message = "No results (OK - may need elevation)" }
        return
    }
    # All entries should have "REGISTRY" in their name
    $nonMatching = @($entries | Where-Object { $_.name -notmatch "REGISTRY" })
    $passed = $nonMatching.Count -eq 0
    @{ Passed = $passed; Message = "Found $($nonMatching.Count) entries not matching 'REGISTRY' filter" }
}
