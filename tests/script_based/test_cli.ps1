<#
.SYNOPSIS
    Tests for CLI argument parsing, help output, and error handling.
#>

function Test-HelpFlag {
    param([string]$LsofwinPath)
    $r = Invoke-Lsofwin -LsofwinPath $LsofwinPath -Arguments @("-h") -CaptureStderr
    $out = $r.OutputString
    $checks = @(
        ($out -match "USAGE:"),
        ($out -match "OPTIONS:"),
        ($out -match "EXAMPLES:"),
        ($out -match "-p"),
        ($out -match "-c"),
        ($out -match "-f"),
        ($out -match "-t"),
        ($out -match "-j"),
        ($out -match "--json"),
        ($out -match "--help"),
        ($out -match "Administrator")
    )
    $failed = @($checks | Where-Object { -not $_ })
    $allPassed = $failed.Count -eq 0
    @{ Passed = $allPassed; Message = "Help output missing expected sections ($($failed.Count) checks failed)" }
}

function Test-HelpLongFlag {
    param([string]$LsofwinPath)
    $r = Invoke-Lsofwin -LsofwinPath $LsofwinPath -Arguments @("--help") -CaptureStderr
    $passed = $r.OutputString -match "USAGE:"
    @{ Passed = $passed; Message = "--help should produce the same output as -h" }
}

function Test-HelpExitCode {
    param([string]$LsofwinPath)
    $r = Invoke-Lsofwin -LsofwinPath $LsofwinPath -Arguments @("-h") -CaptureStderr -SuppressOutput
    @{ Passed = ($r.ExitCode -eq 0); Message = "Expected exit code 0, got $($r.ExitCode)" }
}

function Test-UnknownOptionError {
    param([string]$LsofwinPath)
    $r = Invoke-Lsofwin -LsofwinPath $LsofwinPath -Arguments @("-z") -CaptureStderr
    $passed = ($r.ExitCode -ne 0) -and ($r.OutputString -match "Unknown option")
    @{ Passed = $passed; Message = "Expected non-zero exit and error message for -z" }
}

function Test-MissingPidArgError {
    param([string]$LsofwinPath)
    $r = Invoke-Lsofwin -LsofwinPath $LsofwinPath -Arguments @("-p") -CaptureStderr
    $passed = ($r.ExitCode -ne 0) -and ($r.OutputString -match "requires")
    @{ Passed = $passed; Message = "Expected error for missing -p argument" }
}

function Test-InvalidPidError {
    param([string]$LsofwinPath)
    $r = Invoke-Lsofwin -LsofwinPath $LsofwinPath -Arguments @("-p", "abc") -CaptureStderr
    $passed = ($r.ExitCode -ne 0) -and ($r.OutputString -match "Invalid PID")
    @{ Passed = $passed; Message = "Expected error for invalid PID 'abc'" }
}

function Test-NegativePidError {
    param([string]$LsofwinPath)
    $r = Invoke-Lsofwin -LsofwinPath $LsofwinPath -Arguments @("-p", "-5") -CaptureStderr
    $passed = ($r.ExitCode -ne 0)
    @{ Passed = $passed; Message = "Expected error for negative PID" }
}

function Test-MissingProcessNameArgError {
    param([string]$LsofwinPath)
    $r = Invoke-Lsofwin -LsofwinPath $LsofwinPath -Arguments @("-c") -CaptureStderr
    $passed = ($r.ExitCode -ne 0) -and ($r.OutputString -match "requires")
    @{ Passed = $passed; Message = "Expected error for missing -c argument" }
}

function Test-MissingRegexArgError {
    param([string]$LsofwinPath)
    $r = Invoke-Lsofwin -LsofwinPath $LsofwinPath -Arguments @("-f") -CaptureStderr
    $passed = ($r.ExitCode -ne 0) -and ($r.OutputString -match "requires")
    @{ Passed = $passed; Message = "Expected error for missing -f argument" }
}

function Test-InvalidRegexError {
    param([string]$LsofwinPath)
    $r = Invoke-Lsofwin -LsofwinPath $LsofwinPath -Arguments @("-f", "[bad") -CaptureStderr
    $passed = ($r.ExitCode -ne 0) -and ($r.OutputString -match "Invalid regex")
    @{ Passed = $passed; Message = "Expected error for invalid regex '[bad'" }
}

function Test-MissingTimeoutArgError {
    param([string]$LsofwinPath)
    $r = Invoke-Lsofwin -LsofwinPath $LsofwinPath -Arguments @("-t") -CaptureStderr
    $passed = ($r.ExitCode -ne 0) -and ($r.OutputString -match "requires")
    @{ Passed = $passed; Message = "Expected error for missing -t argument" }
}

function Test-ZeroTimeoutError {
    param([string]$LsofwinPath)
    $r = Invoke-Lsofwin -LsofwinPath $LsofwinPath -Arguments @("-t", "0") -CaptureStderr
    $passed = ($r.ExitCode -ne 0) -and ($r.OutputString -match "Invalid timeout")
    @{ Passed = $passed; Message = "Expected error for timeout of 0" }
}
