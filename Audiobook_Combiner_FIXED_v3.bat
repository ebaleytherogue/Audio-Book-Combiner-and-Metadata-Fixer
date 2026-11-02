@echo off
setlocal EnableExtensions

rem ============================================================
rem General-Purpose Audiobook Combiner
rem
rem Usage:
rem   1) Open Command Prompt in ONE audiobook folder and run this BAT
rem      -or-
rem   2) Drag ONE audiobook folder onto this BAT.
rem
rem It recursively finds ordinary audio files, sorts them naturally,
rem creates one M4B with one chapter per source file, writes audiobook
rem metadata, places the finished M4B one level above the source-book
rem folder, and NEVER deletes the originals.
rem ============================================================

set "BATSELF=%~f0"
set "PS1=%TEMP%\audiobook_combine_%RANDOM%_%RANDOM%.ps1"

if "%~1"=="" (
    set "BOOKROOT=%CD%"
) else (
    set "BOOKROOT=%~1"
)

echo.
echo ============================================================
echo General-Purpose Audiobook Combiner
echo ============================================================
echo.
echo Target folder:
echo   %BOOKROOT%
echo.
echo IMPORTANT:
echo Run this only against ONE audiobook folder.
echo Do NOT point it at your whole Audio Books library or an author folder.
echo.

rem Extract the embedded PowerShell helper from this BAT.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$c=Get-Content -LiteralPath $env:BATSELF; $i=[Array]::IndexOf($c,'#__POWERSHELL__'); if($i -lt 0){exit 9}; $c[($i+1)..($c.Count-1)] | Set-Content -LiteralPath $env:PS1 -Encoding UTF8"

if errorlevel 1 (
    echo [FAILED] Could not prepare the embedded helper script.
    goto :FINISH
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -Root "%BOOKROOT%"
set "RC=%ERRORLEVEL%"

del /q "%PS1%" >nul 2>&1

if not "%RC%"=="0" (
    echo.
    echo The combiner ended with error code %RC%.
)

:FINISH
echo.
pause
endlocal
exit /b

#__POWERSHELL__
param(
    [Parameter(Mandatory=$true)]
    [string]$Root
)

$ErrorActionPreference = 'Stop'

function Find-Tool {
    param([string]$Name)

    $cmd = Get-Command "$Name.exe" -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    if (Test-Path 'C:\apps') {
        $found = Get-ChildItem -LiteralPath 'C:\apps' -Filter "$Name.exe" -File -Recurse -ErrorAction SilentlyContinue |
                 Select-Object -First 1
        if ($found) { return $found.FullName }
    }

    return $null
}

function Natural-Key {
    param([string]$Text)

    return [regex]::Replace(
        $Text.ToLowerInvariant(),
        '\d+',
        { param($m) $m.Value.PadLeft(14,'0') }
    )
}

function Escape-ConcatPath {
    param([string]$Path)

    # FFmpeg concat files use shell-like single-quote escaping.
    return "'" + $Path.Replace("'", "'\''") + "'"
}

function Escape-Metadata {
    param([string]$Text)

    return $Text.Replace('\','\\').Replace('=','\=').Replace(';','\;').Replace('#','\#')
}

try {
    $Root = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\')

    if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
        throw "Target folder does not exist: $Root"
    }

    $ffmpeg  = Find-Tool 'ffmpeg'
    $ffprobe = Find-Tool 'ffprobe'

    if (-not $ffmpeg)  { throw "ffmpeg.exe was not found in PATH or under C:\apps." }
    if (-not $ffprobe) { throw "ffprobe.exe was not found in PATH or under C:\apps." }

    Write-Host ""
    Write-Host "FFmpeg:"
    Write-Host "  $ffmpeg"
    Write-Host "FFprobe:"
    Write-Host "  $ffprobe"
    Write-Host ""

    $extensions = @('.mp3','.m4a','.aac','.wav','.flac','.ogg','.opus','.wma')

    $files = Get-ChildItem -LiteralPath $Root -File -Recurse |
        Where-Object { $extensions -contains $_.Extension.ToLowerInvariant() } |
        Sort-Object { Natural-Key ($_.FullName.Substring($Root.Length).TrimStart('\')) }

    if ($files.Count -lt 2) {
        Write-Host "[STOPPED] Fewer than two source audio files were found."
        Write-Host "There is nothing useful to combine."
        exit 2
    }

    $leaf = Split-Path -Leaf $Root
    $outputFolder = Split-Path -Parent $Root
    $parentName = Split-Path -Leaf $outputFolder

    # Infer year/title from a source-folder name such as:
    #   2003 - Blood Canticle (VC10 - read by David Pittu)
    $year = ''
    if ($leaf -match '^\s*(\d{4})\s*[-_]*\s*') {
        $year = $Matches[1]
    }

    $title = $leaf
    $title = $title -replace '^\s*\d{4}\s*[-_]*\s*', ''
    while ($title -match '\s*\([^()]*\)\s*$') {
        $title = ($title -replace '\s*\([^()]*\)\s*$', '').Trim()
    }
    $title = $title.Trim()
    $title = $title.Trim('-','_',' ')

    if ([string]::IsNullOrWhiteSpace($title)) {
        throw "Could not infer a clean book title from source folder: $leaf"
    }

    # Suggest an author from the parent folder only when that folder does
    # not look like a generic library/container name. The user always gets
    # a chance to accept or replace the suggestion.
    $genericParents = @(
        'audio books','audiobooks','audio book','audiobook',
        'books','book','media','library','dlna_media'
    )

    $authorSuggestion = ''
    if ($parentName -and ($genericParents -notcontains $parentName.ToLowerInvariant())) {
        $authorSuggestion = $parentName
    }

    Write-Host ""
    Write-Host "Metadata check" -ForegroundColor Cyan
    Write-Host "--------------"
    Write-Host "Detected title : $title"
    if ($year) {
        Write-Host "Detected year  : $year"
    } else {
        Write-Host "Detected year  : (none)"
    }

    if ($authorSuggestion) {
        Write-Host "Suggested author: $authorSuggestion"
        $enteredAuthor = Read-Host "Author (press Enter to accept, or type a replacement)"
        if ([string]::IsNullOrWhiteSpace($enteredAuthor)) {
            $author = $authorSuggestion
        } else {
            $author = $enteredAuthor.Trim()
        }
    } else {
        Write-Host "Suggested author: (none - parent folder is '$parentName')"
        do {
            $author = (Read-Host "Enter author").Trim()
        } while ([string]::IsNullOrWhiteSpace($author))
    }

    if ($year) {
        $outputName = "$year - $title.m4b"
    } else {
        $outputName = "$title.m4b"
    }

    # Output always goes ONE LEVEL UP from the source-book folder.
    # Examples:
    #   Audio Books\Anne Rice\Book Folder  -> Audio Books\Anne Rice\Book.m4b
    #   Audio Books\Book Folder            -> Audio Books\Book.m4b
    $output = Join-Path $outputFolder $outputName

    if (Test-Path -LiteralPath $output) {
        Write-Host "[STOPPED] Output already exists:"
        Write-Host "  $output"
        Write-Host ""
        Write-Host "Rename or move that M4B before running the combiner again."
        exit 3
    }

    Write-Host "Source files found: $($files.Count)"
    Write-Host ""
    Write-Host "The files will be combined in THIS order:"
    Write-Host ""

    $n = 1
    foreach ($f in $files) {
        $relative = $f.FullName.Substring($Root.Length).TrimStart('\')
        Write-Host ("{0,4}. {1}" -f $n, $relative)
        $n++
    }

    Write-Host ""
    Write-Host "Output:"
    Write-Host "  $output"
    Write-Host ""
    Write-Host "Embedded metadata:"
    Write-Host "  Title       : $title"
    Write-Host "  Author      : $author"
    Write-Host "  Album       : $title"
    Write-Host "  Album Artist: $author"
    if ($year) {
        Write-Host "  Year        : $year"
    } else {
        Write-Host "  Year        : (not inferred)"
    }
    Write-Host "  Genre       : Audiobook"
    Write-Host "  Media Type  : 2"
    Write-Host ""
    Write-Host "Each source file will become a chapter."
    Write-Host "The originals will NOT be deleted."
    Write-Host ""
    Write-Host "SAFETY CHECK:"
    Write-Host "If the list above contains more than ONE audiobook, cancel now."
    Write-Host ""

    $answer = Read-Host 'Type COMBINE to proceed'
    if ($answer -cne 'COMBINE') {
        Write-Host ""
        Write-Host "[CANCELLED] Nothing was changed."
        exit 0
    }

    $work = Join-Path $env:TEMP ("audiobook_combine_" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $work | Out-Null

    $concatFile = Join-Path $work 'inputs.ffconcat'
    $metaFile   = Join-Path $work 'chapters.ffmeta'

    # Write UTF-8 WITHOUT a BOM. FFmpeg requires "ffconcat" to be the
    # very first bytes of the concat file; Windows PowerShell's -Encoding
    # UTF8 adds a BOM, which FFmpeg interprets as part of the first keyword.
    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($concatFile, "ffconcat version 1.0`r`n", $Utf8NoBom)
    [System.IO.File]::WriteAllText($metaFile,   ";FFMETADATA1`r`n",        $Utf8NoBom)

    # Write book-level metadata before the chapter blocks.
    [System.IO.File]::AppendAllText($metaFile, ("title=" + (Escape-Metadata $title) + "`r`n"), $Utf8NoBom)
    [System.IO.File]::AppendAllText($metaFile, ("artist=" + (Escape-Metadata $author) + "`r`n"), $Utf8NoBom)
    [System.IO.File]::AppendAllText($metaFile, ("album_artist=" + (Escape-Metadata $author) + "`r`n"), $Utf8NoBom)
    [System.IO.File]::AppendAllText($metaFile, ("album=" + (Escape-Metadata $title) + "`r`n"), $Utf8NoBom)
    [System.IO.File]::AppendAllText($metaFile, "genre=Audiobook`r`n", $Utf8NoBom)
    [System.IO.File]::AppendAllText($metaFile, "media_type=2`r`n", $Utf8NoBom)
    if ($year) {
        [System.IO.File]::AppendAllText($metaFile, ("date=" + $year + "`r`n"), $Utf8NoBom)
    }

    $cursorMs = [int64]0
    $chapterNumber = 1

    Write-Host ""
    Write-Host "Building chapter map..."
    Write-Host ""

    foreach ($f in $files) {
        $quoted = Escape-ConcatPath $f.FullName
        [System.IO.File]::AppendAllText($concatFile, ("file " + $quoted + "`r`n"), $Utf8NoBom)

        $durationText = & $ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 -- "$($f.FullName)"
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($durationText)) {
            throw "Could not determine duration of: $($f.FullName)"
        }

        $durationSeconds = [double]::Parse(
            $durationText.Trim(),
            [System.Globalization.CultureInfo]::InvariantCulture
        )

        $durationMs = [int64][math]::Round($durationSeconds * 1000)
        if ($durationMs -lt 1) {
            throw "Invalid duration reported for: $($f.FullName)"
        }

        $startMs = $cursorMs
        $endMs   = $cursorMs + $durationMs
        $cursorMs = $endMs

        $title = Escape-Metadata $f.BaseName

        [System.IO.File]::AppendAllText($metaFile, "[CHAPTER]`r`n", $Utf8NoBom)
        [System.IO.File]::AppendAllText($metaFile, "TIMEBASE=1/1000`r`n", $Utf8NoBom)
        [System.IO.File]::AppendAllText($metaFile, ("START=" + $startMs + "`r`n"), $Utf8NoBom)
        [System.IO.File]::AppendAllText($metaFile, ("END=" + $endMs + "`r`n"), $Utf8NoBom)
        [System.IO.File]::AppendAllText($metaFile, ("title=" + $title + "`r`n"), $Utf8NoBom)

        Write-Host ("  Chapter {0}: {1}" -f $chapterNumber, $f.BaseName)
        $chapterNumber++
    }

    Write-Host ""
    Write-Host "Creating M4B..."
    Write-Host "This can take a while. FFmpeg will show live progress below."
    Write-Host ""

    & $ffmpeg `
        -hide_banner `
        -stats `
        -f concat `
        -safe 0 `
        -i $concatFile `
        -f ffmetadata `
        -i $metaFile `
        -map 0:a:0 `
        -map_metadata 1 `
        -map_chapters 1 `
        -vn `
        -c:a aac `
        -b:a 96k `
        -brand isom `
        -movflags +faststart `
        -- $output

    $ffmpegResult = $LASTEXITCODE

    if ($ffmpegResult -ne 0) {
        if (Test-Path -LiteralPath $output) {
            Remove-Item -LiteralPath $output -Force -ErrorAction SilentlyContinue
        }
        throw "FFmpeg failed with exit code $ffmpegResult. The incomplete M4B, if any, was removed."
    }

    if (-not (Test-Path -LiteralPath $output)) {
        throw "FFmpeg reported success, but the output file was not found."
    }

    $outInfo = Get-Item -LiteralPath $output
    $sizeMB = [math]::Round($outInfo.Length / 1MB, 1)

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "[SUCCESS] Audiobook created"
    Write-Host "============================================================"
    Write-Host ""
    Write-Host "File:"
    Write-Host "  $output"
    Write-Host ""
    Write-Host "Size: $sizeMB MB"
    Write-Host "Chapters: $($files.Count)"
    Write-Host ""
    Write-Host "The original source files and source folder are still untouched."
    Write-Host "The finished M4B was placed directly in the author folder."
    Write-Host "Test the M4B in VLC, Jellyfin, and Volume before deleting anything."
    Write-Host ""

    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    exit 0
}
catch {
    Write-Host ""
    Write-Host "============================================================"
    Write-Host "[FAILED]"
    Write-Host "============================================================"
    Write-Host $_.Exception.Message
    Write-Host ""
    Write-Host "No source audio files were deleted."
    Write-Host ""

    if ($work -and (Test-Path -LiteralPath $work)) {
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }

    exit 1
}
