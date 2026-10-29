# JAMS-not-jelly
Just another media scanning tool for your library to use with Tunarr so that you don't get files that hang anymore
A read-only Bash diagnostic utility for identifying filesystem, permission, symbolic-link, metadata, and video-container problems in large media libraries.

Originally developed to investigate a **Tunarr Local Media scanner failure caused by a broken symbolic link**, which prevented an entire movie library from scanning without identifying the offending file.

## Features

- Filesystem and mount information
- Unreadable and untraversable directories
- Unreadable files
- Broken symbolic links and symbolic-link inventory
- Non-regular filesystem objects
- Zero-byte files and video files
- Empty directories
- Suspicious control characters in filenames
- Video, directory, regular-file, and NFO counts
- Malformed NFO/XML detection
- Duplicate filename detection
- Video container validation using FFprobe
- Full filesystem traversal and error reporting

## Requirements

**Platform:** Linux  
**Shell:** Bash  
**Core utilities:** GNU find, coreutils

Optional dependencies:

| Utility | Purpose |
|---|---|
| `findmnt` | Filesystem mount and option inspection |
| `xmllint` | NFO/XML validation |
| `ffprobe` | Video container validation |

Missing optional utilities cause their respective checks to be skipped.

## Usage

Default movie library:

```bash
./media_scan_tool.sh
```

Specify another library:

```bash
./media_scan_tool.sh /mnt/television
```

Limit the number of reported results per applicable check by editing `MAX_RESULTS` in the script.

## Important Notes

**This tool is read-only with respect to the media library.** It does not rename, modify, repair, or delete media files or metadata. It creates a temporary diagnostic file outside the library during its filesystem traversal check.

FFprobe validation checks whether video containers can be opened and parsed. It does not decode every frame or guarantee that a video file is free of corruption.

Permission checks reflect the effective permissions of the user running the script.

The tool does not automatically follow directory symlinks during traversal.

## Known Issue: Tunarr Local Media Scanner

A broken symbolic link was confirmed to cause Tunarr's Local Media scanner to abort an entire movie-library scan without identifying the offending file.

The **BROKEN SYMLINKS** section is therefore particularly useful when investigating unexplained scanner failures.

## License

Add your preferred open-source license.
