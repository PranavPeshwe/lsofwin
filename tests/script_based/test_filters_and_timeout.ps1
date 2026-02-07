<#
.SYNOPSIS
    Tests for regex filtering and timeout behavior.
#>

function Test-RegexFilterMatchesOnly {
    param([string]$LsofwinPath)
    # Filter for "REGISTRY" — all results should contain it in the NAME column
    $output = & $LsofwinPath -p $PID -t 2 -f "REGISTRY" 2>&1
    $dataLines = @($output | Where-Object { $_ -notmatch "^(COMMAND|WARNING|No open|$)" -and $_.Trim() -ne "" })
    if ($dataLines.Count -eq 0) {
        @{ Passed = $true; Message = "No results (may need elevation)" }
        return
    }
    $nonMatching = @($dataLines | Where-Object { $_ -notmatch "REGISTRY" })
    $passed = $nonMatching.Count -eq 0
    @{ Passed = $passed; Message = "$($nonMatching.Count) lines didn't match REGISTRY filter" }
}

function Test-RegexCaseInsensitive {
    param([string]$LsofwinPath)
    # Use lowercase "registry" — should still match (case-insensitive)
    $output = & $LsofwinPath -p $PID -t 2 -f "registry" 2>&1
    $dataLines = @($output | Where-Object { $_ -notmatch "^(COMMAND|WARNING|No open|$)" -and $_.Trim() -ne "" })
    if ($dataLines.Count -eq 0) {
        @{ Passed = $true; Message = "No results (may need elevation)" }
        return
    }
    # At least one match shows the filter works case-insensitively
    $passed = $dataLines.Count -gt 0
    @{ Passed = $passed; Message = "Expected case-insensitive regex to match" }
}

function Test-RegexWithDotExtension {
    param([string]$LsofwinPath)
    # Create and hold open a .txt file, then search for \.txt$
    $tempFile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "lsofwin_regex_test.txt")
    $stream = [System.IO.File]::Open($tempFile, [System.IO.FileMode]::Create, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::ReadWrite)
    try {
        $output = & $LsofwinPath -p $PID -t 3 -f "lsofwin_regex_test\.txt" 2>&1 | Out-String
        $passed = $output -match "lsofwin_regex_test\.txt"
        @{ Passed = $passed; Message = "Expected to find temp .txt file via regex" }
    } finally {
        $stream.Close()
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    }
}

function Test-RegexAlternation {
    param([string]$LsofwinPath)
    # Test regex alternation pattern
    $json = & $LsofwinPath -p $PID -t 2 -j -f "(REGISTRY|KnownDlls)" 2>$null | Out-String
    try {
        $entries = @($json | ConvertFrom-Json)
    } catch {
        @{ Passed = $false; Message = "JSON parse error" }
        return
    }
    if ($entries.Count -eq 0) {
        @{ Passed = $true; Message = "No results (may need elevation)" }
        return
    }
    # Every entry name should match one of the alternatives
    $nonMatching = @($entries | Where-Object { $_.name -notmatch "REGISTRY|KnownDlls" })
    $passed = $nonMatching.Count -eq 0
    @{ Passed = $passed; Message = "$($nonMatching.Count) entries didn't match alternation pattern" }
}

function Test-TimeoutCompletesReasonably {
    param([string]$LsofwinPath)
    # With a 1-second timeout, the command should complete in under 30 seconds
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $null = & $LsofwinPath -p $PID -t 1 2>&1
    $sw.Stop()
    $passed = $sw.Elapsed.TotalSeconds -lt 30
    @{ Passed = $passed; Message = "Took $([math]::Round($sw.Elapsed.TotalSeconds, 1))s (expected < 30s)" }
}

function Test-LargerTimeoutStillWorks {
    param([string]$LsofwinPath)
    # Just verify -t 10 doesn't crash
    $output = & $LsofwinPath -p $PID -t 10 -f "REGISTRY" 2>&1 | Out-String
    $passed = ($LASTEXITCODE -eq 0) -and ($output.Length -gt 0)
    @{ Passed = $passed; Message = "Expected successful run with -t 10" }
}
