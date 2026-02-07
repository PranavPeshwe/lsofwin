<#
.SYNOPSIS
    Shared helper functions for lsofwin integration tests.
#>

function Invoke-Lsofwin {
    <#
    .SYNOPSIS
        Runs lsofwin.exe, prints the command in blue and its output, returns the output.
    .PARAMETER LsofwinPath
        Path to lsofwin.exe
    .PARAMETER Arguments
        Array of arguments to pass
    .PARAMETER CaptureStderr
        If true, merge stderr into output (2>&1). If false, discard stderr (2>$null).
    #>
    param(
        [string]$LsofwinPath,
        [string[]]$Arguments,
        [switch]$CaptureStderr,
        [switch]$SuppressOutput
    )

    # Build display command string
    $exeName = Split-Path $LsofwinPath -Leaf
    $displayArgs = ($Arguments | ForEach-Object {
        if ($_ -match '\s') { "`"$_`"" } else { $_ }
    }) -join ' '
    $displayCmd = "$exeName $displayArgs".Trim()

    Write-Host "    > $displayCmd" -ForegroundColor Blue

    if ($CaptureStderr) {
        $output = & $LsofwinPath @Arguments 2>&1
    } else {
        $output = & $LsofwinPath @Arguments 2>$null
    }

    $exitCode = $LASTEXITCODE

    if (-not $SuppressOutput) {
        $outputLines = @($output | Out-String -Stream)
        $preview = $outputLines | Select-Object -First 8
        foreach ($line in $preview) {
            Write-Host "      $line" -ForegroundColor DarkGray
        }
        if ($outputLines.Count -gt 8) {
            Write-Host "      ... ($($outputLines.Count - 8) more lines)" -ForegroundColor DarkGray
        }
    }

    return @{
        Output = $output
        ExitCode = $exitCode
        OutputString = ($output | Out-String)
    }
}
