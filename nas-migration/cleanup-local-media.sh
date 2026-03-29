#!/bin/bash

# Cleanup script to remove local media files after successful NAS migration
# WARNING: This will DELETE files from /mnt/nvme/mediastack/library
# Only run this after verifying all services work correctly with NAS

set -e

LOCAL_MEDIA_PATH="/mnt/nvme/mediastack/library"
NAS_MOUNT_POINT="/mnt/nas"                    # Your existing NAS mount
NAS_MEDIA_PATH="/mnt/nas/mediastack/library"  # Matches mediastack.yaml

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}=== WARNING: LOCAL MEDIA CLEANUP ===${NC}\n"
echo -e "${YELLOW}This script will DELETE all files from:${NC}"
echo "  ${LOCAL_MEDIA_PATH}"
echo -e "\n${YELLOW}Make sure:${NC}"
echo "  1. All files have been successfully copied to NAS"
echo "  2. All Docker services are working correctly with NAS"
echo "  3. You have verified media playback works"
echo -e "\n${RED}This action cannot be undone!${NC}\n"

# Verify NAS is mounted
if ! mountpoint -q "${NAS_MOUNT_POINT}"; then
    echo -e "${RED}✗ NAS is not mounted at ${NAS_MOUNT_POINT}${NC}"
    echo "Please mount the NAS first"
    exit 1
fi

# Show what will be deleted
echo -e "${YELLOW}Files to be deleted:${NC}"
du -sh "${LOCAL_MEDIA_PATH}"/* 2>/dev/null || echo "Directory appears empty or doesn't exist"

echo -e "\n${RED}Type 'DELETE' (all caps) to confirm deletion:${NC}"
read CONFIRM

if [ "$CONFIRM" != "DELETE" ]; then
    echo -e "${YELLOW}Cancelled. No files deleted.${NC}"
    exit 0
fi

# Delete files
echo -e "${YELLOW}Deleting local media files...${NC}"
sudo rm -rf "${LOCAL_MEDIA_PATH}"/*

# Verify deletion
if [ -z "$(ls -A ${LOCAL_MEDIA_PATH} 2>/dev/null)" ]; then
    echo -e "${GREEN}✓ Local media files deleted successfully${NC}"
    echo -e "${YELLOW}Note: Directory structure remains. You can remove it manually if desired.${NC}"
else
    echo -e "${RED}✗ Some files may remain. Please check manually.${NC}"
    exit 1
fi
