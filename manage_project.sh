#!/bin/bash

PROJECT_DIR="/home/Saeedullah/Documents/operating system/system_lab/project"
BACKUP_BASE_DIR="/home/Saeedullah/Documents/operating system/system_lab/backup"

DATE_STR=$(date +%Y-%m-%d)
BACKUP_DIR="$BACKUP_BASE_DIR/backup_$DATE_STR"
LOG_FILE="$BACKUP_BASE_DIR/cleanup.log"
REPORT_FILE="$BACKUP_BASE_DIR/report.txt"
ERR_TMP="/tmp/mgmt_err_$(date +%s)"

# Ensure backup base exists
mkdir -p "$BACKUP_BASE_DIR"

# Logging function
log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Initial Log
log_action "Starting maintenance run."

AVAILABLE_KB=$(df "$BACKUP_BASE_DIR" | tail -1 | awk '{print $4}')
if [ "$AVAILABLE_KB" -lt 1024 ]; then
    msg="CRITICAL: Low disk space on backup partition (${AVAILABLE_KB}KB available). Aborting."
    log_action "$msg"
    echo "$msg" >&2
    exit 1
fi

# Initialize Report
{
    echo "Cleanup and Backup Report - $DATE_STR"
    echo "======================================="
    echo "Run Date: $(date)"
    echo "Source: $PROJECT_DIR"
    echo "Backup Destination: $BACKUP_DIR"
    echo "---------------------------------------"
} > "$REPORT_FILE"

TOTAL_DELETED=0
TOTAL_SPACE_CLEARED=0
TOTAL_SPACE_MOVED=0
PERMISSION_ERRORS=0
MOVED_COUNT=0

# ------------------------------------------------------------------------------
# 1. Cleanup Phase: Delete .tmp files older than 7 days
# ------------------------------------------------------------------------------
echo "DELETED FILES (.tmp > 7 days):" >> "$REPORT_FILE"

while IFS= read -r -d '' file; do
    # Get size before removal
    SIZE=$(du -b "$file" | cut -f1)
    
    if rm "$file" 2>"$ERR_TMP"; then
        echo "[DELETED] $file ($SIZE bytes)" >> "$REPORT_FILE"
        log_action "Deleted $file"
        ((TOTAL_DELETED++))
        ((TOTAL_SPACE_CLEARED += SIZE))
    else
        ERR_MSG=$(cat "$ERR_TMP")
        echo "[ERROR] Failed to delete $file: $ERR_MSG" >> "$REPORT_FILE"
        log_action "PERMISSION ERROR (DELETE) on $file: $ERR_MSG"
        ((PERMISSION_ERRORS++))
    fi
done < <(find "$PROJECT_DIR" -type f -name "*.tmp" -mtime +7 -print0)

echo "" >> "$REPORT_FILE"

# ------------------------------------------------------------------------------
# 2. Backup Phase: Move files older than 30 days
# ------------------------------------------------------------------------------
echo "MOVED FILES (Backup > 30 days):" >> "$REPORT_FILE"

# Create backup folder for today
mkdir -p "$BACKUP_DIR"

while IFS= read -r -d '' file; do
    # Calculate relative path to preserve structure
    REL_PATH="${file#$PROJECT_DIR/}"
    DEST_PATH="$BACKUP_DIR/$REL_PATH"
    DEST_SUBDIR=$(dirname "$DEST_PATH")
    
    # Handle Name Conflicts
    if [ -e "$DEST_PATH" ]; then
        CONFLICT_TS=$(date +%H%M%S)
        DEST_PATH="${DEST_PATH}_$CONFLICT_TS"
    fi
    
    # Ensure subdirectory exists in backup
    mkdir -p "$DEST_SUBDIR"
    
    # Move the file
    SIZE=$(du -b "$file" | cut -f1)
    if mv "$file" "$DEST_PATH" 2>"$ERR_TMP"; then
        echo "[MOVED] $file -> $DEST_PATH ($SIZE bytes)" >> "$REPORT_FILE"
        log_action "Moved $file to $DEST_PATH"
        ((MOVED_COUNT++))
        ((TOTAL_SPACE_MOVED += SIZE))
    else
        ERR_MSG=$(cat "$ERR_TMP")
        echo "[ERROR] Failed to move $file: $ERR_MSG" >> "$REPORT_FILE"
        log_action "PERMISSION ERROR (MOVE) on $file: $ERR_MSG"
        ((PERMISSION_ERRORS++))
    fi
done < <(find "$PROJECT_DIR" -type f -mtime +30 -print0)

# ------------------------------------------------------------------------------
# Final Stats & Summary
# ------------------------------------------------------------------------------

TOTAL_CLEARED=$((TOTAL_SPACE_CLEARED + TOTAL_SPACE_MOVED))
# Convert bytes to human readable (approx MB)
CLEARED_MB=$((TOTAL_CLEARED / 1048576))

{
    echo ""
    echo "---------------------------------------"
    echo "SUMMARY:"
    echo "Files Deleted:          $TOTAL_DELETED"
    echo "Files Moved to Backup:  $MOVED_COUNT"
    echo "Space Deleted:          $TOTAL_SPACE_CLEARED bytes"
    echo "Space Moved:            $TOTAL_SPACE_MOVED bytes"
    echo "Total Cleared from Src: $TOTAL_CLEARED bytes (~$CLEARED_MB MB)"
    echo "Permission Errors:      $PERMISSION_ERRORS"
    echo "---------------------------------------"
} >> "$REPORT_FILE"

log_action "Maintenance completed. Deleted: $TOTAL_DELETED, Moved: $MOVED_COUNT, Errors: $PERMISSION_ERRORS"

# Cleanup temp error file
rm -f "$ERR_TMP"

echo "Process completed. Check $REPORT_FILE for details."
