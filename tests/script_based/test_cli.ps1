<#
.SYNOPSIS
    Tests for CLI argument parsing, help output, and error handling.
#>

function Test-HelpFlag {
    param([string]$LsofwinPath)
    $output = & $LsofwinPath -h 2>&1 | Out-String
    $checks = @(
        ($output -match "USAGE:"),
        ($output -match "OPTIONS:"),
        ($output -match "EXAMPLES:"),
        ($output -match "-p"),
        ($output -match "-c"),
        ($output -match "-f"),
        ($output -match "-t"),
        ($output -match "-j"),
        ($output -match "--json"),
        ($output -match "--help"),
        ($output -match "Administrator")
    )
    $failed = @($checks | Where-Object { -not $_ })
    $allPassed = $failed.Count -eq 0
    @{ Passed = $allPassed; Message = "Help output missing expected sections ($($failed.Count) checks failed)" }
}

function Test-HelpLongFlag {
    param([string]$LsofwinPath)
    $output = & $LsofwinPath --help 2>&1 | Out-String
    $passed = $output -match "USAGE:"
    @{ Passed = $passed; Message = "--help should produce the same output as -h" }
}

function Test-HelpExitCode {
    param([string]$LsofwinPath)
    & $LsofwinPath -h > $null 2>&1
    @{ Passed = ($LASTEXITCODE -eq 0); Message = "Expected exit code 0, got $LASTEXITCODE" }
}

function Test-UnknownOptionError {
    param([string]$LsofwinPath)
    $output = & $LsofwinPath -z 2>&1 | Out-String
    $passed = ($LASTEXITCODE -ne 0) -and ($output -match "Unknown option")
    @{ Passed = $passed; Message = "Expected non-zero exit and error message for -z" }
}

function Test-MissingPidArgError {
    param([string]$LsofwinPath)
    $output = & $LsofwinPath -p 2>&1 | Out-String
    $passed = ($LASTEXITCODE -ne 0) -and ($output -match "requires")
    @{ Passed = $passed; Message = "Expected error for missing -p argument" }
}

function Test-InvalidPidError {
    param([string]$LsofwinPath)
    $output = & $LsofwinPath -p "abc" 2>&1 | Out-String
    $passed = ($LASTEXITCODE -ne 0) -and ($output -match "Invalid PID")
    @{ Passed = $passed; Message = "Expected error for invalid PID 'abc'" }
}

function Test-NegativePidError {
    param([string]$LsofwinPath)
    $output = & $LsofwinPath -p "-5" 2>&1 | Out-String
    $passed = ($LASTEXITCODE -ne 0)
    @{ Passed = $passed; Message = "Expected error for negative PID" }
}

function Test-MissingProcessNameArgError {
    param([string]$LsofwinPath)
    $output = & $LsofwinPath -c 2>&1 | Out-String
    $passed = ($LASTEXITCODE -ne 0) -and ($output -match "requires")
    @{ Passed = $passed; Message = "Expected error for missing -c argument" }
}

function Test-MissingRegexArgError {
    param([string]$LsofwinPath)
    $output = & $LsofwinPath -f 2>&1 | Out-String
    $passed = ($LASTEXITCODE -ne 0) -and ($output -match "requires")
    @{ Passed = $passed; Message = "Expected error for missing -f argument" }
}

function Test-InvalidRegexError {
    param([string]$LsofwinPath)
    $output = & $LsofwinPath -f "[bad" 2>&1 | Out-String
    $passed = ($LASTEXITCODE -ne 0) -and ($output -match "Invalid regex")
    @{ Passed = $passed; Message = "Expected error for invalid regex '[bad'" }
}

function Test-MissingTimeoutArgError {
    param([string]$LsofwinPath)
    $output = & $LsofwinPath -t 2>&1 | Out-String
    $passed = ($LASTEXITCODE -ne 0) -and ($output -match "requires")
    @{ Passed = $passed; Message = "Expected error for missing -t argument" }
}

function Test-ZeroTimeoutError {
    param([string]$LsofwinPath)
    $output = & $LsofwinPath -t 0 2>&1 | Out-String
    $passed = ($LASTEXITCODE -ne 0) -and ($output -match "Invalid timeout")
    @{ Passed = $passed; Message = "Expected error for timeout of 0" }
}
