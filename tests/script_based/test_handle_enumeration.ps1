<#
.SYNOPSIS
    Tests that verify lsofwin output against known system state from PowerShell.
#>

function Test-CurrentProcessHandles {
    param([string]$LsofwinPath)
    # lsofwin should find handles for its own parent process (this PowerShell)
    $myPid = $PID
    $output = & $LsofwinPath -p $myPid -t 2 2>&1 | Out-String
    $passed = ($LASTEXITCODE -eq 0) -and ($output -match "pwsh|powershell") -and ($output -match "$myPid")
    @{ Passed = $passed; Message = "Expected to find handles for current PowerShell (PID $myPid)" }
}

function Test-ProcessNameMatchesGetProcess {
    param([string]$LsofwinPath)
    # Pick a well-known process that should be running
    $explorer = Get-Process -Name "explorer" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $explorer) {
        @{ Passed = $true; Message = "Skipped: explorer.exe not running" }
        return
    }
    $explorerPid = $explorer.Id
    $output = & $LsofwinPath -p $explorerPid -t 2 2>&1 | Out-String
    $passed = ($output -match "explorer\.exe") -and ($output -match "$explorerPid")
    @{ Passed = $passed; Message = "Expected explorer.exe with PID $explorerPid in output" }
}

function Test-ProcessNameFilter {
    param([string]$LsofwinPath)
    # Filter by "explorer" — all results should be for explorer.exe
    $output = & $LsofwinPath -c "explorer" -t 2 2>&1
    $dataLines = @($output | Where-Object { $_ -notmatch "^(COMMAND|WARNING|$)" -and $_.Trim() -ne "" })
    if ($dataLines.Count -eq 0) {
        @{ Passed = $true; Message = "Skipped: no results for explorer (may need Admin)" }
        return
    }
    $allMatch = @($dataLines | Where-Object { $_ -notmatch "explorer" }).Count -eq 0
    @{ Passed = $allMatch; Message = "All results should contain 'explorer' in COMMAND column" }
}

function Test-PidFilterOnlyShowsTargetPid {
    param([string]$LsofwinPath)
    $myPid = $PID
    # JSON mode for easy parsing — all entries should have matching PID
    $json = & $LsofwinPath -p $myPid -t 2 -j 2>$null | Out-String
    try {
        $entries = @($json | ConvertFrom-Json)
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
    # Use a very high PID that won't exist
    $output = & $LsofwinPath -p 9999999 -t 1 2>&1 | Out-String
    $passed = ($LASTEXITCODE -eq 0) -and ($output -match "No open handles found")
    @{ Passed = $passed; Message = "Expected empty results for nonexistent PID" }
}

function Test-TempFileIsVisible {
    param([string]$LsofwinPath)
    # Create a temp file, hold it open, and verify lsofwin can see it
    $tempFile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "lsofwin_test_$([guid]::NewGuid().ToString('N').Substring(0,8)).tmp")
    $stream = [System.IO.File]::Open($tempFile, [System.IO.FileMode]::Create, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::ReadWrite)
    try {
        $myPid = $PID
        $fileName = [System.IO.Path]::GetFileName($tempFile)
        $output = & $LsofwinPath -p $myPid -t 3 -f $fileName 2>&1 | Out-String
        $passed = $output -match $fileName
        @{ Passed = $passed; Message = "Expected to find temp file '$fileName' in output for PID $myPid" }
    } finally {
        $stream.Close()
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    }
}

function Test-UserMatchesWhoami {
    param([string]$LsofwinPath)
    # The USER column for our own process should match whoami
    $expectedUser = whoami
    $json = & $LsofwinPath -p $PID -t 2 -j 2>$null | Out-String
    try {
        $entries = @($json | ConvertFrom-Json)
    } catch {
        @{ Passed = $false; Message = "Failed to parse JSON" }
        return
    }
    if ($entries.Count -eq 0) {
        @{ Passed = $false; Message = "No entries found" }
        return
    }
    # Compare case-insensitively
    $firstUser = $entries[0].user
    $passed = $firstUser -ieq $expectedUser
    @{ Passed = $passed; Message = "Expected user '$expectedUser', got '$firstUser'" }
}
