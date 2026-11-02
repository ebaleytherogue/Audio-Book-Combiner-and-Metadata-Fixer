@echo off
setlocal EnableExtensions
title M4B Metadata Fixer

rem ============================================================
rem  M4B Metadata Fixer
rem  - Drag one .m4b file onto this BAT, OR run it in a folder
rem    containing exactly one .m4b file.
rem  - Infers:
rem      Author      = parent folder name
rem      Year        = leading YYYY in filename, if present
rem      Title       = filename minus leading "YYYY - "
rem                    and trailing parenthetical narrator/info
rem  - Writes:
rem      title, artist, album_artist, album, genre=Audiobook,
rem      date (when found), media_type=2
rem  - Preserves chapters and existing cover art.
rem  - Does NOT re-encode audio.
rem  - Replaces the original only after a successful remux.
rem ============================================================

set "SELF=%~f0"
set "PS1=%TEMP%\M4B_Metadata_Fixer_%RANDOM%_%RANDOM%.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$p='%SELF%'; $o='%PS1%'; $lines=Get-Content -LiteralPath $p; $i=[Array]::IndexOf($lines,'#__POWERSHELL__'); if($i -lt 0){exit 2}; $lines[($i+1)..($lines.Length-1)] | Set-Content -LiteralPath $o -Encoding UTF8"
if errorlevel 1 (
    echo.
    echo ERROR: Could not extract the embedded PowerShell helper.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*
set "RC=%ERRORLEVEL%"

del /q "%PS1%" >nul 2>&1
exit /b %RC%

#__POWERSHELL__
param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$InputArgs
)

$ErrorActionPreference = 'Stop'

function Find-Tool([string]$name) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $fallback = "C:\apps\ffmpeg\bin\$name.exe"
    if (Test-Path -LiteralPath $fallback) { return $fallback }

    throw "$name.exe was not found in PATH or C:\apps\ffmpeg\bin."
}

function Pause-Exit([int]$code = 0) {
    Write-Host ""
    Read-Host "Press Enter to close"
    exit $code
}

try {
    $ffmpeg = Find-Tool 'ffmpeg'
    $ffprobe = Find-Tool 'ffprobe'

    $target = $null

    if ($InputArgs.Count -ge 1 -and $InputArgs[0]) {
        $candidate = $InputArgs[0].Trim('"')

        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $item = Get-Item -LiteralPath $candidate
            if ($item.Extension -ine '.m4b') {
                throw "The supplied file is not an .m4b file."
            }
            $target = $item
        }
        elseif (Test-Path -LiteralPath $candidate -PathType Container) {
            $files = @(Get-ChildItem -LiteralPath $candidate -File -Filter *.m4b)
            if ($files.Count -ne 1) {
                throw "That folder contains $($files.Count) M4B files. It must contain exactly one."
            }
            $target = $files[0]
        }
        else {
            throw "The supplied path does not exist: $candidate"
        }
    }
    else {
        $files = @(Get-ChildItem -LiteralPath (Get-Location).Path -File -Filter *.m4b)
        if ($files.Count -ne 1) {
            throw "This folder contains $($files.Count) M4B files. Drag the desired M4B onto this BAT, or run the BAT in a folder containing exactly one M4B."
        }
        $target = $files[0]
    }

    $dir = $target.Directory.FullName
    $base = [System.IO.Path]::GetFileNameWithoutExtension($target.Name)

    $author = $target.Directory.Name

    $year = ''
    if ($base -match '^\s*(\d{4})\s*[-_]*\s*') {
        $year = $Matches[1]
    }

    $title = $base
    $title = $title -replace '^\s*\d{4}\s*[-_]*\s*', ''

    while ($title -match '\s*\([^()]*\)\s*$') {
        $title = ($title -replace '\s*\([^()]*\)\s*$', '').Trim()
    }

    # ASCII-only cleanup to avoid code-page issues in .BAT extraction.
    $title = $title.Trim()
    $title = $title.Trim('-','_',' ')

    if ([string]::IsNullOrWhiteSpace($title)) {
        throw "Could not infer a title from the filename."
    }

    Write-Host ""
    Write-Host "M4B Metadata Fixer" -ForegroundColor Cyan
    Write-Host "------------------"
    Write-Host "File        : $($target.FullName)"
    Write-Host "Title       : $title"
    Write-Host "Author      : $author"
    Write-Host "Album       : $title"
    Write-Host "Album Artist: $author"
    Write-Host "Genre       : Audiobook"
    if ($year) {
        Write-Host "Year        : $year"
    } else {
        Write-Host "Year        : (not inferred; existing date tag will be retained if present)"
    }
    Write-Host "Media Type  : 2 (Audiobook)"
    Write-Host ""
    Write-Host "Audio will be stream-copied; it will NOT be re-encoded."
    Write-Host "Chapters and any embedded cover image will be preserved."
    Write-Host ""

    $confirm = Read-Host 'Type FIX to write this metadata'
    if ($confirm -cne 'FIX') {
        Write-Host "Cancelled."
        Pause-Exit 0
    }

    $temp = Join-Path $dir ($base + '.metadatafix.tmp.m4b')
    $backup = Join-Path $dir ($base + '.before-metadata-fix.bak.m4b')

    if (Test-Path -LiteralPath $temp) {
        Remove-Item -LiteralPath $temp -Force
    }

    if (Test-Path -LiteralPath $backup) {
        throw "Backup file already exists:`n$backup`nRename/delete it before running this fixer again."
    }

    $args = @(
        '-hide_banner',
        '-stats',
        '-i', $target.FullName,
        '-map', '0:a:0',
        '-map', '0:v?',
        '-map_metadata', '0',
        '-map_chapters', '0',
        '-c', 'copy',
        '-metadata', "title=$title",
        '-metadata', "artist=$author",
        '-metadata', "album_artist=$author",
        '-metadata', "album=$title",
        '-metadata', 'genre=Audiobook',
        '-metadata', 'media_type=2',
        '-brand', 'isom'
    )

    if ($year) {
        $args += @('-metadata', "date=$year")
    }

    $args += @('-movflags', '+faststart', $temp)

    Write-Host ""
    Write-Host "Writing corrected M4B..." -ForegroundColor Cyan
    & $ffmpeg @args
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $temp)) {
        if (Test-Path -LiteralPath $temp) {
            Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
        }
        throw "FFmpeg failed. The original M4B was left untouched."
    }

    $probeJson = & $ffprobe -v error -print_format json -show_format -show_streams -show_chapters -- $temp
    if ($LASTEXITCODE -ne 0) {
        Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
        throw "ffprobe could not verify the new file. The original M4B was left untouched."
    }

    $probe = $probeJson | ConvertFrom-Json
    $audioCount = @($probe.streams | Where-Object { $_.codec_type -eq 'audio' }).Count
    $chapterCount = @($probe.chapters).Count

    if ($audioCount -lt 1) {
        Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
        throw "Verification found no audio stream. The original M4B was left untouched."
    }

    Move-Item -LiteralPath $target.FullName -Destination $backup
    try {
        Move-Item -LiteralPath $temp -Destination $target.FullName
    }
    catch {
        Move-Item -LiteralPath $backup -Destination $target.FullName -ErrorAction SilentlyContinue
        throw
    }

    Write-Host ""
    Write-Host "SUCCESS" -ForegroundColor Green
    Write-Host "Corrected file : $($target.FullName)"
    Write-Host "Backup original: $backup"
    Write-Host "Audio streams  : $audioCount"
    Write-Host "Chapters       : $chapterCount"
    Write-Host ""
    Write-Host "After confirming the corrected book works in Jellyfin/Volume,"
    Write-Host "you may delete the .before-metadata-fix.bak.m4b backup."
    Pause-Exit 0
}
catch {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Pause-Exit 1
}
