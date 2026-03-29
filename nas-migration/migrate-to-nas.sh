#!/bin/bash

# Media Server Migration Script: RPi Local Storage -> TrueNAS
# This script migrates media from /mnt/nvme/mediastack/library to NAS
#
# For SMB-mounted NAS: run with sudo so rsync can create dirs/files on the share:
#   sudo ./migrate-to-nas.sh

set -e  # Exit on error

# Configuration
# NAS is already mounted at /mnt/nas (SMB data share)
NAS_MOUNT_POINT="/mnt/nas"                        # Your existing mount
NAS_MEDIA_PATH="/mnt/nas/mediastack/library"      # Target path (matches mediastack.yaml)
LOCAL_MEDIA_PATH="/mnt/nvme/mediastack/library"   # Current local storage on Pi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Media Server Migration to TrueNAS ===${NC}\n"

# Step 1: Verify NAS is mounted at /mnt/nas
echo -e "${YELLOW}Step 1: Verifying NAS is mounted at ${NAS_MOUNT_POINT}...${NC}"
if ! mountpoint -q "${NAS_MOUNT_POINT}"; then
    echo -e "${RED}✗ NAS is not mounted at ${NAS_MOUNT_POINT}${NC}"
    echo "Please mount your SMB share first, then run this script again."
    exit 1
fi
echo -e "${GREEN}✓ NAS is mounted${NC}\n"

# Step 2: Create directory structure on NAS (minimal; rsync will create the rest to match Pi)
# Pi has: downloads/nzbget/{completed,incomplete,nzb,queue,tmp,torrents}, downloads/qbittorrent/{completed,incomplete,torrents}, movies, music, tvshows
sudo mkdir -p "${NAS_MEDIA_PATH}"/{downloads/{nzbget/{completed,incomplete,torrents},qbittorrent/{completed,incomplete,torrents}},movies,music,tvshows}
sudo chown -R 1000:1000 "${NAS_MEDIA_PATH}"
echo -e "${GREEN}✓ Directory structure created${NC}\n"

# Step 3: Dry run rsync to show what will be copied
# --no-owner --no-group: SMB often doesn't support chown/chgrp; avoids "Operation not permitted"
echo -e "${YELLOW}Step 3: Performing dry-run rsync (showing what will be copied)...${NC}"
rsync -avh --no-owner --no-group --dry-run --progress "${LOCAL_MEDIA_PATH}/" "${NAS_MEDIA_PATH}/"
echo -e "\n${YELLOW}Review the above output. Press Enter to continue with actual copy, or Ctrl+C to cancel...${NC}"
read

# Step 4: Actual rsync copy
echo -e "${YELLOW}Step 4: Copying files to NAS (this may take a while)...${NC}"
rsync -avh --no-owner --no-group --progress --partial "${LOCAL_MEDIA_PATH}/" "${NAS_MEDIA_PATH}/"
echo -e "${GREEN}✓ Files copied successfully${NC}\n"

# Step 5: Verify copy
echo -e "${YELLOW}Step 5: Verifying copy...${NC}"
LOCAL_SIZE=$(du -sb "${LOCAL_MEDIA_PATH}" | cut -f1)
NAS_SIZE=$(du -sb "${NAS_MEDIA_PATH}" | cut -f1)

if [ "$LOCAL_SIZE" -eq "$NAS_SIZE" ]; then
    echo -e "${GREEN}✓ Verification passed: Sizes match${NC}"
    echo "  Local: $(du -sh "${LOCAL_MEDIA_PATH}" | cut -f1)"
    echo "  NAS:   $(du -sh "${NAS_MEDIA_PATH}" | cut -f1)"
else
    echo -e "${RED}✗ Size mismatch detected!${NC}"
    echo "  Local: ${LOCAL_SIZE} bytes"
    echo "  NAS:   ${NAS_SIZE} bytes"
    echo -e "${YELLOW}Please review before proceeding${NC}"
    exit 1
fi

echo -e "\n${GREEN}=== Migration Complete ===${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo "1. mediastack.yaml already uses ${NAS_MEDIA_PATH}"
echo "2. Restart Docker services: docker-compose -f mediastack.yaml up -d"
echo "3. Verify all services can access media on NAS"
echo "4. Run cleanup-local-media.sh to remove local files (after verification)"
echo "5. Optional: Clean up downloads/qbittorrent/completed on NAS (see NAS-MIGRATION-GUIDE.md)"
