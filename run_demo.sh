#!/bin/bash

BASE="/home/abdulrehman/Documents/operating system/system_lab"
PROJECT="$BASE/project"
BACKUP="$BASE/backup"

# 1. Setup
echo "--- Setting up test project ---"
mkdir -p "$PROJECT/user1/logs"
mkdir -p "$PROJECT/user2/work"
mkdir -p "$BACKUP"

# Create dummy files
touch -d "10 days ago" "$PROJECT/user1/junk.tmp"
touch -d "8 days ago" "$PROJECT/old_session.tmp"
touch -d "2 days ago" "$PROJECT/recent.tmp"
touch -d "40 days ago" "$PROJECT/user1/logs/old_system.log"
touch -d "35 days ago" "$PROJECT/user2/work/archive.zip"
echo "Large file" > "$PROJECT/large_data.txt"
truncate -s 2M "$PROJECT/large_data.txt"
touch -d "45 days ago" "$PROJECT/large_data.txt"
touch -d "15 days ago" "$PROJECT/active.log"

# 2. Run Script
echo "--- Running Maintenance ---"
bash "$BASE/manage_project.sh"

# 3. Show Results
echo "--- Report ---"
cat "$BACKUP/report.txt"
echo "--- Backup Folder Content ---"
ls -R "$BACKUP/backup_$(date +%Y-%m-%d)"
