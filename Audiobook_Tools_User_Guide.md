# Audiobook Combiner & Metadata Fixer
## User Guide — Version 3 Combiner / Version 2 Metadata Fixer

**Platform:** Windows 11  
**Required software:** FFmpeg and FFprobe  
**Script files:**
- `Audiobook_Combiner_FIXED_v3.bat`
- `M4B_Metadata_Fixer_v2.bat`

## Table of Contents

1. [What the Two Scripts Do](#1-what-the-two-scripts-do)
2. [Before You Begin](#2-before-you-begin)
3. [Using the Audiobook Combiner](#3-using-the-audiobook-combiner)
4. [Using the M4B Metadata Fixer](#4-using-the-m4b-metadata-fixer)
5. [Which BAT Should I Use?](#5-which-bat-should-i-use)
6. [Troubleshooting](#6-troubleshooting)
7. [Recommended Workflow](#7-recommended-workflow)
8. [Script Version Reference](#8-script-version-reference)

---

## 1. What the Two Scripts Do

These scripts perform two different jobs.

### Audiobook Combiner — v3

Use this when an audiobook consists of **multiple audio files** and you want one `.m4b` audiobook containing chapters.

The combiner:
- Finds audio files in the selected book folder and its subfolders.
- Sorts them in natural numerical order.
- Combines them into a single M4B audiobook.
- Creates a chapter for each original audio file.
- Encodes the audio as AAC at 96 kbps.
- Adds book title, author, album, genre, and year metadata.
- Places the completed M4B in the parent folder.
- Leaves the original audio files untouched.

### M4B Metadata Fixer — v2

Use this when you **already have a single M4B file**, but its metadata is incorrect, incomplete, or missing.

The fixer:
- Identifies the title and year from the filename.
- Identifies the author from the containing folder.
- Corrects the audiobook's embedded metadata.
- Preserves the audio without re-encoding.
- Preserves existing chapters.
- Preserves embedded cover art when present.
- Creates a backup of the original file.

**Important:** The fixer does not merge audio files, and the combiner is not intended for correcting an already-combined M4B.

---

## 2. Before You Begin

### FFmpeg installation

Both scripts require:

`C:\apps\ffmpeg\bin\ffmpeg.exe`

`C:\apps\ffmpeg\bin\ffprobe.exe`

This is the installation location we previously configured.

### Prepare the BAT files

Extract both BAT files from the `.7z` archive into a convenient folder, such as:

`C:\apps\Audiobook Tools\`

Do not attempt to execute them from inside the archive preview.

### Recommended library organization

Our successful library arrangement was:

```text
H:\DLNA_Media\Books\Audio Books\
    Anne Rice\
        2002 - Blackwood Farm.m4b
        2003 - Blood Canticle.m4b
        2009 - Angel Time.m4b

    Peter F. Hamilton\
        Book Title.m4b
```

Keep finished M4Bs directly inside their author's folder. This arrangement worked with both Jellyfin and the Volume audiobook player.

---

## 3. Using the Audiobook Combiner

### Example: A multi-file audiobook

Suppose you have:

```text
H:\DLNA_Media\Books\Audio Books\
    Anne Rice\
        1982 - Cry to Heaven (read by Ray Hagen)\
            1_ Part I\
                Chapter 01.mp3
                Chapter 02.mp3
            2_ Part II\
                Chapter 01.mp3
                Chapter 02.mp3
            ...
            8_ Afterword.mp3
```

You do not need to move the chapter files out of their subfolders.

### Step-by-step instructions

**Step 1 — Find the source book folder.**

Open Windows File Explorer and locate the folder containing the original audio files.

**Step 2 — Drag the entire book folder onto the BAT file.**

Drag:

`1982 - Cry to Heaven (read by Ray Hagen)`

onto:

`Audiobook_Combiner_FIXED_v3.bat`

Drag the **folder**, not an individual MP3.

**Step 3 — Review the metadata.**

The script examines the folder name and proposes metadata.

For this example:

| Field | Value |
|---|---|
| Title | Cry to Heaven |
| Author | Anne Rice |
| Year | 1982 |
| Album | Cry to Heaven |

The author is suggested from the parent folder.

Press **Enter** to accept the suggested author, or type a replacement author name.

If the parent folder has a generic name such as `Audio Books`, the script asks you to enter the author manually.

**Step 4 — Inspect the audio-file order.**

The script displays the files it intends to combine.

Verify that the chapters appear in the correct order.

It uses natural sorting, meaning Chapter 2 comes before Chapter 10, even if the filenames do not have leading zeros.

It also sorts using the relative folder paths, allowing numbered Part I, Part II, etc. folders to remain intact.

**Step 5 — Confirm the operation.**

When satisfied, type:

`COMBINE`

and press Enter.

**Step 6 — Wait for FFmpeg to finish.**

FFmpeg will encode the audio into AAC and assemble the M4B.

Long audiobooks can take considerable time.

Do not close the command window during processing.

**Step 7 — Find the finished audiobook.**

The output is written **one folder level above** the source book folder.

For example:

```text
Anne Rice\
    1982 - Cry to Heaven.m4b

    1982 - Cry to Heaven (read by Ray Hagen)\
        1_ Part I\
        2_ Part II\
        ...
```

The source folder remains untouched.

**Step 8 — Verify the result.**

Open the M4B in VLC, Jellyfin, or Volume.

Check that:
- The audiobook plays.
- The beginning and ending sound correct.
- The duration looks reasonable.
- Chapters are present and in order.
- The title and author are correct.

Only after successful verification should you consider deleting the original multi-file source folder.

### Supported source formats

The combiner searches for:

`.mp3`, `.m4a`, `.aac`, `.wav`, `.flac`, `.ogg`, `.opus`, `.wma`

It requires at least two audio files.

It does not directly process `.zab` archives or existing `.m4b` files.

### Important limitations

- Each original audio file becomes one chapter. It does not automatically detect chapter boundaries inside a single audio file.
- It re-encodes the audio to AAC at 96 kbps.
- It does not preserve embedded cover artwork from the source files.
- It will not overwrite an existing output M4B with the same filename.
- A misleading folder name can produce an incorrect inferred title or year.

---

## 4. Using the M4B Metadata Fixer

### When to use it

Use the fixer when an existing M4B:
- Displays an incorrect title.
- Has no author information.
- Has an incorrect album name.
- Is missing its publication year.
- Needs consistent audiobook metadata for Jellyfin or Volume.

### Step-by-step instructions

**Step 1 — Place the M4B directly inside its author's folder.**

For example:

```text
H:\DLNA_Media\Books\Audio Books\
    Anne Rice\
        2003 - Blood Canticle.m4b
```

This is important because the fixer determines the author from the M4B's immediate parent folder.

**Step 2 — Check the filename.**

The recommended filename format is:

`YYYY - Book Title.m4b`

Examples:

`2002 - Blackwood Farm.m4b`

`2003 - Blood Canticle.m4b`

`2009 - Angel Time.m4b`

The leading four-digit year becomes the embedded date metadata.

The script also removes trailing parenthetical information, such as `(VC10 - read by David Pittu)`, when deriving the title.

**Step 3 — Drag the M4B onto the fixer BAT.**

Drag:

`2003 - Blood Canticle.m4b`

onto:

`M4B_Metadata_Fixer_v2.bat`

Drag the **file**, not its folder.

**Step 4 — Review the proposed metadata.**

For this example, the script should derive:

| Field | Value |
|---|---|
| Title | Blood Canticle |
| Artist | Anne Rice |
| Album Artist | Anne Rice |
| Album | Blood Canticle |
| Year | 2003 |
| Genre | Audiobook |
| Media Type | 2 |

Unlike the combiner, the fixer relies on the parent folder for the author and does not provide the same author-override dialog.

**Step 5 — Confirm the operation.**

Type:

`FIX`

and press Enter.

**Step 6 — Wait for completion.**

The fixer copies the existing audio streams into a new M4B with corrected metadata.

It does **not** re-encode the audio, so processing is usually much faster than running the combiner.

**Step 7 — Inspect the results.**

The corrected audiobook retains its original filename.

The fixer also creates a backup with a name resembling:

`2003 - Blood Canticle.before-metadata-fix.bak.m4b`

The backup contains the original file from before the metadata correction.

**Step 8 — Verify and clean up.**

Test the corrected M4B in Jellyfin and Volume.

Confirm the chapter list, audio playback, and metadata.

Once satisfied, you can delete the `.before-metadata-fix.bak.m4b` backup to reclaim disk space.

### Important limitations

- It handles one M4B at a time.
- It does not merge separate audio files.
- It cannot correct the author automatically if the parent folder is incorrectly named.
- It does not restore chapters that never existed.
- It does not recover missing audio or improve audio quality.
- It does not overwrite the original without first making a backup.

---

## 5. Which BAT Should I Use?

| Situation | Use |
|---|---|
| Book contains 30 MP3 chapters | Combiner v3 |
| Book has multiple numbered subfolders containing MP3s | Combiner v3 |
| Book contains WAV or FLAC chapter files | Combiner v3 |
| Book already has one M4B but wrong metadata | Metadata Fixer v2 |
| M4B has no author or year | Metadata Fixer v2 |
| M4B is already working perfectly | Neither |
| ZAB archive contains one M4B | Extract M4B; fixer only if needed |
| M4B is missing chapter markers | Neither script can reconstruct them automatically |

---

## 6. Troubleshooting

### Combiner says there are too few audio files

Verify that the source folder contains at least two supported audio files.

An existing single M4B is not a valid combiner input.

### Combiner reports that the output already exists

The combiner intentionally refuses to overwrite an existing output file.

Inspect the existing M4B before proceeding. Rename or relocate it only if you know it is safe.

### Chapters are out of order

Check the source-order preview before typing `COMBINE`.

If necessary, rename the source audio files or folders so that their numerical ordering is unambiguous, then restart the script.

### Author is incorrect

For the combiner, type the correct author when the metadata prompt appears.

For the fixer, move the M4B into the correct author's folder before running it.

### The audiobook appears in Jellyfin but not Volume

Our earlier troubleshooting established that placing M4Bs directly in the author folder resolved discovery problems for Blood Canticle.

Check the folder hierarchy first, then rescan the Jellyfin library.

### The BAT cannot find FFmpeg

Confirm that these files exist:

```text
C:\apps\ffmpeg\bin\ffmpeg.exe
C:\apps\ffmpeg\bin\ffprobe.exe
```

### Can I delete the original files?

Yes, but only after verifying the completed audiobook.

The combiner does not delete source files. The metadata fixer creates a backup that can be deleted after successful verification.

---

## 7. Recommended Workflow

For every new audiobook:

1. Place the source folder inside the correct author's folder.
2. If it contains multiple audio files, run the **Combiner v3**.
3. Inspect the proposed author and chapter order.
4. Type `COMBINE` and wait.
5. Test the completed M4B in Jellyfin and Volume.
6. Delete the old source folder only after confirming the output is good.
7. If you instead receive an existing M4B with poor metadata, run the **Metadata Fixer v2**.
8. Verify the corrected M4B and remove its backup when satisfied.

**Golden rule:** Never delete the original audio until you have verified the replacement.

---

## 8. Script Version Reference

| Script | Version | Confirmation |
|---|---|---|
| Audiobook_Combiner_FIXED_v3.bat | v3 | `COMBINE` |
| M4B_Metadata_Fixer_v2.bat | v2 | `FIX` |

These are the versions we successfully used for the Anne Rice audiobook library project.

The v3 combiner was successfully tested on *Angel Time*, with playback and chapters confirmed in both Jellyfin and Volume.

The v2 metadata fixer was successfully tested on *Blood Canticle*, correcting its metadata while preserving all 31 chapters.

**End of User Guide**
