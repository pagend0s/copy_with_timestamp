#Requires -Version 5.1
<#
.SYNOPSIS
  Copies or moves files from Source to Destination grouped by YYYY\MM
  (or by YYYY with -YearOnly) based on LastWriteTime or CreationTime.
  Supports GUI, name collision handling, progress, and optional CSV report.
  Compatible with Windows PowerShell 5.1.

.PARAMETER Source
  Source folder. If omitted and -UseGui is set, a folder dialog will appear.

.PARAMETER Destination
  Destination folder. Will be created if missing. If omitted and -UseGui is set, a folder dialog will appear.

.PARAMETER TimeField
  Date field to group by: LastWriteTime (default) or CreationTime.

.PARAMETER Move
  Move files instead of copying.

.PARAMETER UseGui
  Use folder selection dialogs for Source/Destination when not provided as parameters.

.PARAMETER KeepStructure
  Preserve relative source directory tree under YYYY\MM (or YYYY with -YearOnly).

.PARAMETER YearOnly
  Group files by year only (YYYY) without month subfolders.

.PARAMETER ReportPath
  Optional CSV path to write a report.

.EXAMPLE
  .\copy_with_date_stamp.ps1 -UseGui

.EXAMPLE
  .\copy_with_date_stamp.ps1 -Source "D:\Foto" -Destination "E:\Archive" -TimeField CreationTime

.EXAMPLE
  .\copy_with_date_stamp.ps1 -Source "C:\SRC" -Destination "D:\DST" -Move -KeepStructure -ReportPath "D:\report.csv" -WhatIf

.EXAMPLE
  # Year-only grouping (no months)
  .\copy_with_date_stamp.ps1 -Source "D:\Foto" -Destination "E:\Archive" -YearOnly
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $false)]
    [string]$Source,

    [Parameter(Mandatory = $false)]
    [string]$Destination,

    [ValidateSet('LastWriteTime','CreationTime')]
    [string]$TimeField = 'LastWriteTime',

    [switch]$Move,
    [switch]$UseGui,
    [switch]$KeepStructure,

    # NEW: only group by year
    [switch]$YearOnly,

    [string]$ReportPath
)

#region Helpers

function Select-Folder {
    param(
        [Parameter(Mandatory)][string]$Title,
        [string]$Initial = "C:\Users"
    )
    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description  = $Title
    if (Test-Path -LiteralPath $Initial -PathType Container) {
        $dlg.SelectedPath = $Initial
    }
    $result = $dlg.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return $dlg.SelectedPath
    }
    throw "Operation cancelled by user."
}

function Get-UniqueTargetPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$DestDir,
        [Parameter(Mandatory)][string]$FileName
    )
    if (-not (Test-Path -LiteralPath $DestDir -PathType Container)) {
        New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
    }

    $target = Join-Path $DestDir $FileName
    if (-not (Test-Path -LiteralPath $target)) {
        return $target
    }

    $base = [IO.Path]::GetFileNameWithoutExtension($FileName)
    $ext  = [IO.Path]::GetExtension($FileName)
    $n = 1
    do {
        $candidate = Join-Path $DestDir ("{0} ({1}){2}" -f $base, $n, $ext)
        $n++
    } while (Test-Path -LiteralPath $candidate)

    return $candidate
}

function Get-RelativeDirectory {
    <#
      Returns file's directory path relative to SourceRoot.
      Returns "" if file is directly in SourceRoot.
    #>
    param(
        [Parameter(Mandatory)][string]$SourceRoot,
        [Parameter(Mandatory)][string]$FileDirectory
    )
    $srcPath = (Resolve-Path -LiteralPath $SourceRoot).ProviderPath.TrimEnd('\') + '\'
    $dirPath = (Resolve-Path -LiteralPath $FileDirectory).ProviderPath.TrimEnd('\') + '\'

    $srcUri = [Uri]::new($srcPath)
    $dirUri = [Uri]::new($dirPath)

    $rel = $srcUri.MakeRelativeUri($dirUri).ToString()
    $rel = [Uri]::UnescapeDataString($rel).Replace('/', '\')
    if ($rel -eq ".\") { return "" }
    return $rel.TrimEnd('\')
}

function Test-PathRelationship {
    <#
      Checks whether A contains B or B contains A to prevent copy/move into each other.
      Returns "AInB", "BInA" or $false.
    #>
    param(
        [Parameter(Mandatory)][string]$A,
        [Parameter(Mandatory)][string]$B
    )
    try {
        $A = (Resolve-Path -LiteralPath $A).ProviderPath.TrimEnd('\') + '\'
        $B = (Resolve-Path -LiteralPath $B).ProviderPath.TrimEnd('\') + '\'
    } catch {
        return $false
    }
    if ($A.StartsWith($B, [System.StringComparison]::InvariantCultureIgnoreCase)) { return "AInB" }
    if ($B.StartsWith($A, [System.StringComparison]::InvariantCultureIgnoreCase)) { return "BInA" }
    return $false
}

#endregion Helpers

# ---- Runtime ----
$ti_sta = "2.1"
Write-Host ("{0}{1}" -f (' ' * (([Math]::Max(0, $Host.UI.RawUI.BufferSize.Width / 2) - [Math]::Floor($Null.Length / 2)))), "WELCOME TO COPY WITH TIMESTAMP version: " ) -ForegroundColor Green -NoNewline
Write-Host "$ti_sta" -ForegroundColor Yellow

try {
    # GUI selection if parameters are not provided
    if ($UseGui -and -not $Source)      { $Source      = Select-Folder -Title "Select SOURCE folder" }
    if ($UseGui -and -not $Destination) { $Destination = Select-Folder -Title "Select DESTINATION folder" }

    if (-not $Source)      { throw "Missing -Source (or use -UseGui)." }
    if (-not $Destination) { throw "Missing -Destination (or use -UseGui)." }

    if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
        throw "Source does not exist or is not a folder: $Source"
    }

    if (-not (Test-Path -LiteralPath $Destination -PathType Container)) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    }

    # Validate path relationship to avoid self-recursion
    $rel = Test-PathRelationship -A $Source -B $Destination
    if ($rel -eq "BInA") {
        throw "Destination is inside Source. Change Destination to avoid recursion.`nSource=$Source`nDestination=$Destination"
    }
    if ($Move.IsPresent -and $rel -eq "AInB") {
        throw "Source is inside Destination - moving in this configuration is risky.`nSource=$Source`nDestination=$Destination"
    }

    Write-Host "Collecting file list..." -ForegroundColor Green
    $files = Get-ChildItem -LiteralPath $Source -File -Recurse -ErrorAction Stop
    $total = $files.Count
    if ($total -eq 0) {
        Write-Host "No files to process in: $Source" -ForegroundColor Yellow
        return
    }

    $processed = 0
    $failed = 0
    $skipped = 0
    $i = 0
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    $rows = New-Object System.Collections.Generic.List[object]

    foreach ($f in $files) {
        $i++

        # Determine date and grouping keys
        $dt    = $f.$TimeField
        $year  = $dt.ToString('yyyy')
        $month = $dt.ToString('MM')

        # Destination directory (year-only vs year+month)
        if ($YearOnly) {
            $destDir = Join-Path $Destination $year
        } else {
            $destDir = Join-Path $Destination (Join-Path $year $month)
        }

        if ($KeepStructure) {
            $relDir = Get-RelativeDirectory -SourceRoot $Source -FileDirectory $f.DirectoryName
            if ($relDir) {
                $destDir = Join-Path $destDir $relDir
            }
        }

        $target = Get-UniqueTargetPath -DestDir $destDir -FileName $f.Name

        $actionVerb = "Copying"
        $actionName = "Copy"
        if ($Move.IsPresent) {
            $actionVerb = "Moving"
            $actionName = "Move"
        }

        $progressTarget = if ($YearOnly) { "$year" } else { "$year\$month" }
        Write-Progress -Activity "$actionVerb by $TimeField -> $progressTarget" `
                       -Status    ("{0} / {1}: {2}" -f $i, $total, $f.FullName)

        try {
            if ($PSCmdlet.ShouldProcess($f.FullName, "$actionVerb -> $target")) {
                if ($Move.IsPresent) {
                    Move-Item -LiteralPath $f.FullName -Destination $target -ErrorAction Stop
                } else {
                    Copy-Item -LiteralPath $f.FullName -Destination $target -ErrorAction Stop
                }
                $processed++

                if ($ReportPath) {
                    $rows.Add([pscustomobject]@{
                        TimeField = $TimeField
                        TimeValue = $dt
                        Year      = $year
                        Month     = if ($YearOnly) { "" } else { $month }
                        Source    = $f.FullName
                        Target    = $target
                        Action    = $actionName
                        Status    = 'OK'
                        Error     = $null
                    })
                }
            } else {
                $skipped++
                if ($ReportPath) {
                    $rows.Add([pscustomobject]@{
                        TimeField = $TimeField
                        TimeValue = $dt
                        Year      = $year
                        Month     = if ($YearOnly) { "" } else { $month }
                        Source    = $f.FullName
                        Target    = $target
                        Action    = $actionName
                        Status    = 'WhatIf/Skipped'
                        Error     = $null
                    })
                }
            }
        }
        catch {
            $failed++
            Write-Warning "Error for file: $($f.FullName) -> $target`n$($_.Exception.Message)"
            if ($ReportPath) {
                $rows.Add([pscustomobject]@{
                    TimeField = $TimeField
                    TimeValue = $dt
                    Year      = $year
                    Month     = if ($YearOnly) { "" } else { $month }
                    Source    = $f.FullName
                    Target    = $target
                    Action    = $actionName
                    Status    = 'ERROR'
                    Error     = $_.Exception.Message
                })
            }
        }
    }

    $sw.Stop()
    Write-Progress -Activity "Completed" -Completed

    if ($ReportPath) {
        try {
            $reportDir = Split-Path -Path $ReportPath -Parent
            if ($reportDir -and -not (Test-Path -LiteralPath $reportDir)) {
                New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
            }
            $rows | Export-Csv -Path $ReportPath -NoTypeInformation -Encoding UTF8
            Write-Host "Report saved: $ReportPath" -ForegroundColor Cyan
        } catch {
            Write-Warning "Failed to write CSV report: $($_.Exception.Message)"
        }
    }

    $finalVerb = if ($Move.IsPresent) { "Moved" } else { "Copied" }
    Write-Host ("{0}: {1} | Skipped: {2} | Errors: {3} | Time: {4}" -f $finalVerb, $processed, $skipped, $failed, $sw.Elapsed) -ForegroundColor Green

    Start-Process explorer.exe $Destination
}
catch {
    Write-Error $_
}
