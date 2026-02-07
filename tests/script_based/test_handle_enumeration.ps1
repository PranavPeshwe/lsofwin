<#
.SYNOPSIS
    Tests that verify lsofwin output against known system state from PowerShell.
#>

function Test-CurrentProcessHandles {
    param([string]$LsofwinPath)
    $myPid = $PID
    $r = Invoke-Lsofwin -LsofwinPath $LsofwinPath -Arguments @("-p", "$myPid", "-t", "2") -CaptureStderr
    $passed = ($r.ExitCode -eq 0) -and ($r.OutputString -match "pwsh|powershell") -and ($r.OutputString -match "$myPid")
    @{ Passed = $passed; Message = "Expected to find handles for current PowerShell (PID $myPid)" }
}

function Test-ProcessNameMatchesGetProcess {
    param([string]$LsofwinPath)
    $explorer = Get-Process -Name "explorer" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $explorer) {
        @{ Passed = $true; Message = "Skipped: explorer.exe not running" }
        return
    }
    $explorerPid = $explorer.Id
    $r = Invoke-Lsofwin -LsofwinPath $LsofwinPath -Arguments @("-p", "$explorerPid", "-t", "2") -CaptureStderr
    $passed = ($r.OutputString -match "explorer\.exe") -and ($r.OutputString -match "$explorerPid")
    @{ Passed = $passed; Message = "Expected explorer.exe with PID $explorerPid in output" }
}

function Test-ProcessNameFilter {
    param([string]$LsofwinPath)
    $r = Invoke-Lsofwin -LsofwinPath $LsofwinPath -Arguments @("-c", "explorer", "-t", "2") -CaptureStderr
    $dataLines = @($r.Output | Where-Object { $_ -notmatch "^(COMMAND|WARNING|$)" -and $_.ToString().Trim() -ne "" })
    if ($dataLines.Count -eq 0) {
        @{ Passed = $true; Message = "Skipped: no results for explorer (may need Admin)" }
        return
    }
    $allMatch = @($dataLines | Where-Object { $_.ToString() -notmatch "explorer" }).Count -eq 0
    @{ Passed = $allMatch; Message = "All results should contain 'explorer' in COMMAND column" }
}

function Test-PidFilterOnlyShowsTargetPid {
    param([string]$LsofwinPath)
    $myPid = $PID
    $r = Invoke-Lsofwin -LsofwinPath $LsofwinPath -Arguments @("-p", "$myPid", "-t", "2", "-j")
    try {
        $entries = @($r.OutputString | ConvertFrom-Json)
    } catch {
        @{ Passed = $false; Message = "Failed to parse JSON output" }
        return
    }
    if ($entries.Count -eq 0) {
        @{ Passed = $false; Message = "Expected at least one handle for PID $myPid" }
        return
    }
    $wrongPid = @($entries | Where-Object { $_.pid -ne $myPid })
    $passed = $wrongPid.Count -eq 0
    @{ Passed = $passed; Message = "Found $($wrongPid.Count) entries with wrong PID (expected only $myPid)" }
}

function Test-NonexistentPidReturnsEmpty {
    param([string]$LsofwinPath)
    $r = Invoke-Lsofwin -LsofwinPath $LsofwinPath -Arguments @("-p", "9999999", "-t", "1") -CaptureStderr
    $passed = ($r.ExitCode -eq 0) -and ($r.OutputString -match "No open handles found")
    @{ Passed = $passed; Message = "Expected empty results for nonexistent PID" }
}

function Test-TempFileIsVisible {
    param([string]$LsofwinPath)
    $tempFile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "lsofwin_test_$([guid]::NewGuid().ToString('N').Substring(0,8)).tmp")
    $stream = [System.IO.File]::Open($tempFile, [System.IO.FileMode]::Create, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::ReadWrite)
    try {
        $myPid = $PID
        $fileName = [System.IO.Path]::GetFileName($tempFile)
        $r = Invoke-Lsofwin -LsofwinPath $LsofwinPath -Arguments @("-p", "$myPid", "-t", "3", "-f", $fileName) -CaptureStderr
        $passed = $r.OutputString -match $fileName
        @{ Passed = $passed; Message = "Expected to find temp file '$fileName' in output for PID $myPid" }
    } finally {
        $stream.Close()
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    }
}

function Test-UserMatchesWhoami {
    param([string]$LsofwinPath)
    $expectedUser = whoami
    $r = Invoke-Lsofwin -LsofwinPath $LsofwinPath -Arguments @("-p", "$PID", "-t", "2", "-j")
    try {
        $entries = @($r.OutputString | ConvertFrom-Json)
    } catch {
        @{ Passed = $false; Message = "Failed to parse JSON" }
        return
    }
    if ($entries.Count -eq 0) {
        @{ Passed = $false; Message = "No entries found" }
        return
    }
    $firstUser = $entries[0].user
    $passed = $firstUser -ieq $expectedUser
    @{ Passed = $passed; Message = "Expected user '$expectedUser', got '$firstUser'" }
}
