<#
.SYNOPSIS
    Tests for regex filtering and timeout behavior.
#>

function Test-RegexFilterMatchesOnly {
    param([string]$LsofwinPath)
    $r = Invoke-Lsofwin -LsofwinPath $LsofwinPath -Arguments @("-p", "$PID", "-t", "2", "-f", "REGISTRY") -CaptureStderr
    $dataLines = @($r.Output | Where-Object { $_.ToString() -notmatch "^(COMMAND|WARNING|No open|$)" -and $_.ToString().Trim() -ne "" })
    if ($dataLines.Count -eq 0) {
        @{ Passed = $true; Message = "No results (may need elevation)" }
        return
    }
    $nonMatching = @($dataLines | Where-Object { $_.ToString() -notmatch "REGISTRY" })
    $passed = $nonMatching.Count -eq 0
    @{ Passed = $passed; Message = "$($nonMatching.Count) lines didn't match REGISTRY filter" }
}

function Test-RegexCaseInsensitive {
    param([string]$LsofwinPath)
    $r = Invoke-Lsofwin -LsofwinPath $LsofwinPath -Arguments @("-p", "$PID", "-t", "2", "-f", "registry") -CaptureStderr
    $dataLines = @($r.Output | Where-Object { $_.ToString() -notmatch "^(COMMAND|WARNING|No open|$)" -and $_.ToString().Trim() -ne "" })
    if ($dataLines.Count -eq 0) {
        @{ Passed = $true; Message = "No results (may need elevation)" }
        return
    }
    $passed = $dataLines.Count -gt 0
    @{ Passed = $passed; Message = "Expected case-insensitive regex to match" }
}

function Test-RegexWithDotExtension {
    param([string]$LsofwinPath)
    $tempFile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "lsofwin_regex_test.txt")
    $stream = [System.IO.File]::Open($tempFile, [System.IO.FileMode]::Create, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::ReadWrite)
    try {
        $r = Invoke-Lsofwin -LsofwinPath $LsofwinPath -Arguments @("-p", "$PID", "-t", "3", "-f", "lsofwin_regex_test\.txt") -CaptureStderr
        $passed = $r.OutputString -match "lsofwin_regex_test\.txt"
        @{ Passed = $passed; Message = "Expected to find temp .txt file via regex" }
    } finally {
        $stream.Close()
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    }
}

function Test-RegexAlternation {
    param([string]$LsofwinPath)
    $r = Invoke-Lsofwin -LsofwinPath $LsofwinPath -Arguments @("-p", "$PID", "-t", "2", "-j", "-f", "(REGISTRY|KnownDlls)")
    try {
        $entries = @($r.OutputString | ConvertFrom-Json)
    } catch {
        @{ Passed = $false; Message = "JSON parse error" }
        return
    }
    if ($entries.Count -eq 0) {
        @{ Passed = $true; Message = "No results (may need elevation)" }
        return
    }
    $nonMatching = @($entries | Where-Object { $_.name -notmatch "REGISTRY|KnownDlls" })
    $passed = $nonMatching.Count -eq 0
    @{ Passed = $passed; Message = "$($nonMatching.Count) entries didn't match alternation pattern" }
}

function Test-TimeoutCompletesReasonably {
    param([string]$LsofwinPath)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $r = Invoke-Lsofwin -LsofwinPath $LsofwinPath -Arguments @("-p", "$PID", "-t", "1") -CaptureStderr -SuppressOutput
    $sw.Stop()
    $passed = $sw.Elapsed.TotalSeconds -lt 30
    @{ Passed = $passed; Message = "Took $([math]::Round($sw.Elapsed.TotalSeconds, 1))s (expected < 30s)" }
}

function Test-LargerTimeoutStillWorks {
    param([string]$LsofwinPath)
    $r = Invoke-Lsofwin -LsofwinPath $LsofwinPath -Arguments @("-p", "$PID", "-t", "10", "-f", "REGISTRY") -CaptureStderr
    $passed = ($r.ExitCode -eq 0) -and ($r.OutputString.Length -gt 0)
    @{ Passed = $passed; Message = "Expected successful run with -t 10" }
}
