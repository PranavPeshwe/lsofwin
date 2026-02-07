<#
.SYNOPSIS
    Test runner for lsofwin PowerShell-based integration tests.

.DESCRIPTION
    Runs all test scripts in this directory and reports results.
    Each test script should define functions named Test-* that return
    a hashtable with 'Passed' (bool) and 'Message' (string).

    Requires PowerShell 7+ (pwsh) for reliable JSON handling.

.PARAMETER LsofwinPath
    Path to the lsofwin.exe binary. Defaults to the Release build.
#>
[CmdletBinding()]
param(
    [string]$LsofwinPath = "$PSScriptRoot\..\..\build\Release\lsofwin.exe"
)

$ErrorActionPreference = 'Continue'
Set-StrictMode -Version Latest

if (-not (Test-Path $LsofwinPath)) {
    # Fall back to Debug
    $LsofwinPath = "$PSScriptRoot\..\..\build\Debug\lsofwin.exe"
}

if (-not (Test-Path $LsofwinPath)) {
    Write-Host "ERROR: lsofwin.exe not found. Build the project first." -ForegroundColor Red
    exit 1
}

$LsofwinPath = (Resolve-Path $LsofwinPath).Path
Write-Host "=== lsofwin Integration Tests ===" -ForegroundColor Cyan
Write-Host "Binary: $LsofwinPath" -ForegroundColor DarkGray
Write-Host ""

# Load shared helpers
. "$PSScriptRoot\test_helpers.ps1"

$testFiles = Get-ChildItem $PSScriptRoot -Filter "test_*.ps1" | Where-Object { $_.Name -ne "test_helpers.ps1" } | Sort-Object Name
$totalTests = 0
$passedTests = 0
$failedTests = 0
$failedNames = @()

foreach ($file in $testFiles) {
    Write-Host "--- $($file.Name) ---" -ForegroundColor Yellow
    . $file.FullName

    $testFunctions = Get-Command -Name "Test-*" -CommandType Function -ErrorAction SilentlyContinue |
        Where-Object { $_.ScriptBlock.File -eq $file.FullName }

    foreach ($fn in $testFunctions) {
        $totalTests++
        $testName = $fn.Name
        try {
            $result = & $fn.Name -LsofwinPath $LsofwinPath
            if ($result.Passed) {
                Write-Host "  PASS: $testName" -ForegroundColor Green
                $passedTests++
            } else {
                Write-Host "  FAIL: $testName - $($result.Message)" -ForegroundColor Red
                $failedTests++
                $failedNames += $testName
            }
        } catch {
            Write-Host "  FAIL: $testName - Exception: $_" -ForegroundColor Red
            $failedTests++
            $failedNames += $testName
        }
    }

    # Clean up test functions to avoid cross-file conflicts
    Get-Command -Name "Test-*" -CommandType Function -ErrorAction SilentlyContinue |
        Where-Object { $_.ScriptBlock.File -eq $file.FullName } |
        ForEach-Object { Remove-Item "Function:\$($_.Name)" -ErrorAction SilentlyContinue }
}

Write-Host ""
Write-Host "=== Results ===" -ForegroundColor Cyan
Write-Host "  Total:  $totalTests"
Write-Host "  Passed: $passedTests" -ForegroundColor Green
if ($failedTests -gt 0) {
    Write-Host "  Failed: $failedTests" -ForegroundColor Red
    foreach ($name in $failedNames) {
        Write-Host "    - $name" -ForegroundColor Red
    }
    exit 1
} else {
    Write-Host "  Failed: 0" -ForegroundColor Green
    exit 0
}
