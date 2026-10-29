
#!/usr/bin/env bash

# ==============================================================================
# Media Library Scan Tool
# ==============================================================================
#
# A read-only diagnostic utility for identifying filesystem, metadata,
# and media-container issues that can interfere with media library scanners.
#
# Originally developed to troubleshoot a Tunarr Local Media scanner failure
# caused by a broken symbolic link.
#
# Usage:
#   ./media_scan_tool.sh
#   ./media_scan_tool.sh /mnt/television
#
# Default library: /mnt/movies
#
# Optional dependencies:
#   - util-linux (findmnt)
#   - libxml2-utils (xmllint)
#   - FFmpeg (ffprobe)
#
# No media files, directories, or metadata are modified or deleted.
# ==============================================================================

LIBRARY="${1:-/mnt/movies}"
MAX_RESULTS=100

VIDEO_EXTENSIONS=(
    mkv mp4 avi m4v mov
    mpg mpeg ts m2ts mts
    webm wmv vob
)

# ==============================================================================
# Helpers
# ==============================================================================

section() {
    printf '\n%s\n%s\n%s\n' \
        "==============================================================================" \
        "$1" \
        "=============================================================================="
}

# Build a reusable GNU find expression for supported video extensions.
VIDEO_FIND_ARGS=("(")

for ext in "${VIDEO_EXTENSIONS[@]}"; do
    if (( ${#VIDEO_FIND_ARGS[@]} > 1 )); then
        VIDEO_FIND_ARGS+=("-o")
    fi

    VIDEO_FIND_ARGS+=("-iname" "*.${ext}")
done

VIDEO_FIND_ARGS+=(")")

# ==============================================================================
# Preflight
# ==============================================================================

if [[ ! -d "$LIBRARY" ]]; then
    printf 'ERROR: Library does not exist or is not a directory:\n%s\n' \
        "$LIBRARY" >&2
    exit 1
fi

printf 'Media Library Scan Tool\n'
printf 'Library: %s\n' "$LIBRARY"
printf 'Started: %s\n\n' "$(date)"

# ==============================================================================
# Filesystem / Mount Information
# ==============================================================================

section "FILESYSTEM / MOUNT"

echo "Filesystem:"
df -h "$LIBRARY"

echo
echo "Mount:"
if command -v findmnt >/dev/null 2>&1; then
    findmnt -T "$LIBRARY" || true

    echo
    echo "Filesystem type and options:"
    findmnt -T "$LIBRARY" -o FSTYPE,OPTIONS -n || true
else
    echo "SKIPPED: findmnt is not installed."
fi

# ==============================================================================
# Directory Permissions
# ==============================================================================

section "UNREADABLE DIRECTORIES"

find "$LIBRARY" -type d ! -readable -print 2>&1 |
    head -n "$MAX_RESULTS"

section "UNTRAVERSABLE DIRECTORIES"

find "$LIBRARY" -type d ! -executable -print 2>&1 |
    head -n "$MAX_RESULTS"

section "UNREADABLE FILES"

find "$LIBRARY" -type f ! -readable -print 2>&1 |
    head -n "$MAX_RESULTS"

# ==============================================================================
# Symbolic Links
# ==============================================================================

section "BROKEN SYMLINKS"

# A broken symlink originally exposed the Tunarr scanner failure.
find "$LIBRARY" -xtype l -print 2>&1 |
    head -n "$MAX_RESULTS"

section "ALL SYMLINKS"

find "$LIBRARY" -type l -printf '%p -> %l\n' 2>&1 |
    head -n "$MAX_RESULTS"

# ==============================================================================
# Filesystem Object Integrity
# ==============================================================================

section "FIFO / SOCKET / DEVICE / OTHER NON-REGULAR OBJECTS"

find "$LIBRARY" \
    ! -type f \
    ! -type d \
    ! -type l \
    -print 2>&1 |
    head -n "$MAX_RESULTS"

section "ZERO-BYTE FILES"

find "$LIBRARY" -type f -size 0 -print 2>&1 |
    head -n "$MAX_RESULTS"

section "ZERO-BYTE VIDEO FILES"

find "$LIBRARY" -type f -size 0 \
    "${VIDEO_FIND_ARGS[@]}" -print 2>&1 |
    head -n "$MAX_RESULTS"

section "EMPTY DIRECTORIES"

find "$LIBRARY" -type d -empty -print 2>&1 |
    head -n "$MAX_RESULTS"

# ==============================================================================
# Filename Integrity
# ==============================================================================

section "FILES WITH SUSPICIOUS CONTROL CHARACTERS"

# Newlines, carriage returns, and tabs can confuse media scanners
# and scripts that assume filenames contain no control characters.

find "$LIBRARY" -print0 2>/dev/null |
    while IFS= read -r -d '' path; do
        name="${path##*/}"

        if [[ "$name" == *$'\n'* ||
              "$name" == *$'\r'* ||
              "$name" == *$'\t'* ]]; then
            printf '%q\n' "$path"
        fi
    done |
    head -n "$MAX_RESULTS"

# ==============================================================================
# Library Statistics
# ==============================================================================

section "VIDEO FILE COUNT"

VIDEO_COUNT=$(
    find "$LIBRARY" -type f \
        "${VIDEO_FIND_ARGS[@]}" -printf '.\n' 2>/dev/null |
        wc -l
)

echo "$VIDEO_COUNT"

section "DIRECTORY COUNT"

find "$LIBRARY" -type d -printf '.\n' 2>/dev/null |
    wc -l

section "REGULAR FILE COUNT"

find "$LIBRARY" -type f -printf '.\n' 2>/dev/null |
    wc -l

section "NFO FILE COUNT"

find "$LIBRARY" -type f -iname '*.nfo' -printf '.\n' 2>/dev/null |
    wc -l

# ==============================================================================
# Metadata Validation
# ==============================================================================

section "MALFORMED NFO/XML FILES"

if command -v xmllint >/dev/null 2>&1; then
    find "$LIBRARY" -type f -iname '*.nfo' -print0 2>/dev/null |
        while IFS= read -r -d '' file; do
            if ! xmllint --noout "$file" >/dev/null 2>&1; then
                printf '%s\n' "$file"
            fi
        done |
        head -n "$MAX_RESULTS"
else
    echo "SKIPPED: xmllint is not installed."
fi

# ==============================================================================
# Duplicate Filename Detection
# ==============================================================================

section "DUPLICATE FILENAMES"

# Detect identical basenames across different directories.
# This does not compare file contents.

find "$LIBRARY" -type f -printf '%f\n' 2>/dev/null |
    sort |
    uniq -d |
    head -n "$MAX_RESULTS"

# ==============================================================================
# Video Container Validation
# ==============================================================================

section "FFPROBE VIDEO VALIDATION"

if command -v ffprobe >/dev/null 2>&1; then
    echo "Checking whether each video container can be opened by ffprobe..."
    echo "This may take a long time on large libraries."
    echo

    find "$LIBRARY" -type f \
        "${VIDEO_FIND_ARGS[@]}" -print0 2>/dev/null |
        while IFS= read -r -d '' file; do
            if ! ffprobe \
                -v error \
                -show_entries format=duration \
                -of default=noprint_wrappers=1:nokey=1 \
                "$file" >/dev/null 2>&1; then

                printf '%s\n' "$file"
            fi
        done
else
    echo "SKIPPED: ffprobe is not installed."
fi

# ==============================================================================
# Full Filesystem Traversal
# ==============================================================================

section "FULL TREE WALK / FILESYSTEM ERRORS"

TREE_ERRORS=$(mktemp) || exit 1
trap 'rm -f "$TREE_ERRORS"' EXIT

find "$LIBRARY" -print >/dev/null 2>"$TREE_ERRORS"

if [[ -s "$TREE_ERRORS" ]]; then
    cat "$TREE_ERRORS"
else
    echo "PASS: Full directory tree traversed without filesystem errors."
fi

# ==============================================================================
# Summary
# ==============================================================================

section "SUMMARY"

printf 'Library:       %s\n' "$LIBRARY"
printf 'Video files:   %s\n' "$VIDEO_COUNT"
printf 'Completed:     %s\n' "$(date)"

echo
echo "Scan complete."
echo
echo "IMPORTANT:"
echo "Any output under BROKEN SYMLINKS should be investigated."
echo
echo "A broken symlink was confirmed to cause Tunarr's Local Media scanner"
echo "to abort an entire movie-library scan without identifying the"
echo "offending file."
