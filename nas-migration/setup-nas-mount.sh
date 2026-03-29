#!/bin/bash

# Setup script for permanent NAS mount on Raspberry Pi
# This creates an fstab entry for automatic mounting

set -e

# Configuration - UPDATE THESE VALUES
NAS_IP="192.168.1.XXX"           # Your TrueNAS IP address
NAS_SHARE="mediastack"            # SMB/NFS share name on TrueNAS
NAS_USER="your_username"          # NAS username
NAS_MOUNT_POINT="/mnt/nas/mediastack"  # Local mount point for NAS

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Setting up permanent NAS mount ===${NC}\n"

# Create mount point
sudo mkdir -p "${NAS_MOUNT_POINT}"
sudo chown 1000:1000 "${NAS_MOUNT_POINT}"

# Create credentials file for SMB (more secure than putting password in fstab)
echo -e "${YELLOW}Creating credentials file...${NC}"
CREDENTIALS_FILE="/root/.nas_credentials"
sudo bash -c "cat > ${CREDENTIALS_FILE} <<EOF
username=${NAS_USER}
password=\$(cat)
EOF"

echo "Please enter your NAS password:"
read -s NAS_PASS
echo "${NAS_PASS}" | sudo tee "${CREDENTIALS_FILE}" > /dev/null
sudo chmod 600 "${CREDENTIALS_FILE}"
echo -e "${GREEN}✓ Credentials file created${NC}\n"

# Add to fstab for SMB/CIFS
echo -e "${YELLOW}Adding mount to /etc/fstab...${NC}"
FSTAB_ENTRY="//${NAS_IP}/${NAS_SHARE} ${NAS_MOUNT_POINT} cifs credentials=${CREDENTIALS_FILE},uid=1000,gid=1000,iocharset=utf8,file_mode=0777,dir_mode=0777,noauto,user 0 0"

# Check if entry already exists
if grep -q "${NAS_MOUNT_POINT}" /etc/fstab; then
    echo -e "${YELLOW}Mount point already in fstab, skipping...${NC}"
else
    echo "${FSTAB_ENTRY}" | sudo tee -a /etc/fstab
    echo -e "${GREEN}✓ Added to /etc/fstab${NC}\n"
fi

# For NFS (alternative - uncomment if using NFS):
# FSTAB_ENTRY_NFS="${NAS_IP}:/mnt/pool/${NAS_SHARE} ${NAS_MOUNT_POINT} nfs rw,noatime,vers=4.1,noauto,user 0 0"
# echo "${FSTAB_ENTRY_NFS}" | sudo tee -a /etc/fstab

echo -e "${GREEN}=== Setup Complete ===${NC}"
echo -e "${YELLOW}To mount manually:${NC} mount ${NAS_MOUNT_POINT}"
echo -e "${YELLOW}To test fstab entry:${NC} sudo mount -a"
