# NAS Migration Guide

This guide will help you migrate your media server from local Raspberry Pi storage to TrueNAS, keeping the same file structure.

## Source folder structure (RPi)

What gets synced from the Pi (`/mnt/nvme/mediastack/library`), excluding `lost+found`:

- **config** – stays on Pi (not part of library migration)
- **library/downloads/nzbget/** – completed, incomplete, nzb, queue (history, stats), tmp, torrents, logs
- **library/downloads/qbittorrent/** – completed, incomplete, torrents
- **library/movies/** – final movie library
- **library/music/** – final music library
- **library/tvshows/** – final TV library

The migration script rsyncs the **entire** library tree, so the NAS will match the Pi (including NZBGet’s extra dirs). After migration you can optionally clean up `downloads/qbittorrent/completed` on the NAS to remove redundancy (many of those files are already in movies/tvshows).

## If your NAS is already mounted at `/mnt/nas`

If the SMB share is already mounted at `/mnt/nas`:

1. Skip **Step 2** (Set up permanent NAS mount) — no need to run `setup-nas-mount.sh`.
2. Ensure `mediastack/library` exists under the share (the migration script will create it).
3. Run **Step 3** (Migrate media files); the script only checks that `/mnt/nas` is mounted, then creates dirs and rsyncs.

## Prerequisites

- TrueNAS share configured and accessible
- NAS IP address and share name
- NAS username and password
- SSH access to Raspberry Pi

## Migration Steps

### Step 1: Configure NAS Connection Details

Edit the migration scripts and update these variables:

**In `migrate-to-nas.sh`** (when NAS is already mounted at `/mnt/nas`, no edits needed):
- Script uses `NAS_MOUNT_POINT=/mnt/nas` and `NAS_MEDIA_PATH=/mnt/nas/mediastack/library`

**In `setup-nas-mount.sh`** (only if you need to set up the mount):
- `NAS_IP`, `NAS_SHARE`, `NAS_USER`, and the mount point (e.g. `/mnt/nas`)

### Step 2: Set Up Permanent NAS Mount

1. Make the setup script executable:
   ```bash
   chmod +x setup-nas-mount.sh
   ```

2. Run the setup script:
   ```bash
   ./setup-nas-mount.sh
   ```

   This will:
   - Create the mount point directory
   - Set up credentials file
   - Add entry to `/etc/fstab` for automatic mounting

3. Test the mount (if using setup-nas-mount.sh; otherwise your share may already be at `/mnt/nas`):
   ```bash
   sudo mount /mnt/nas
   ```

4. Verify it's mounted:
   ```bash
   df -h | grep nas
   ```

### Step 3: Migrate Media Files

1. Make the migration script executable:
   ```bash
   chmod +x migrate-to-nas.sh
   ```

2. **IMPORTANT**: Stop Docker services to prevent file changes during migration:
   ```bash
   docker-compose -f mediastack.yaml down
   ```

3. Run the migration script:
   ```bash
   ./migrate-to-nas.sh
   ```

   The script will:
   - Mount the NAS (if not already mounted)
   - Create directory structure on NAS
   - Perform a dry-run to show what will be copied
   - Copy all files using rsync (preserving structure and permissions)
   - Verify the copy was successful

### Step 4: Update Docker Compose Configuration

The `mediastack.yaml` file has already been updated to use `/mnt/nas/mediastack/library` instead of `/mnt/nvme/mediastack/library`.

**Verify the changes:**
```bash
grep -n "/mnt/nas" mediastack.yaml
```

You should see all services now pointing to the NAS mount.

### Step 5: Update Service Configurations

After switching to NAS, you may need to update paths in service configurations:

#### Sonarr
1. Go to Settings → Media Management → Root Folders
2. Update the root folder path if needed (should be `/data` inside container)

#### Radarr
1. Go to Settings → Media Management → Root Folders
2. Update the root folder path if needed

#### Lidarr
1. Go to Settings → Media Management → Root Folders
2. Update the root folder path if needed

#### Plex
1. Go to Settings → Libraries
2. Verify library paths are correct (should be `/data/movies`, `/data/tvshows`, etc.)

### Step 6: Restart Services and Verify

1. Ensure NAS is mounted at `/mnt/nas`:
   ```bash
   mountpoint -q /mnt/nas && echo "Mounted" || sudo mount /mnt/nas
   ```

2. Start Docker services:
   ```bash
   docker-compose -f mediastack.yaml up -d
   ```

3. Verify services are running:
   ```bash
   docker-compose -f mediastack.yaml ps
   ```

4. Check service logs for any errors:
   ```bash
   docker-compose -f mediastack.yaml logs -f
   ```

5. Test media access:
   - Open Plex and verify libraries show content
   - Check Sonarr/Radarr can see existing media
   - Try playing a file through Plex

### Step 7: Clean Up Local Files (After Verification)

**ONLY run this after you've verified everything works correctly!**

1. Make the cleanup script executable:
   ```bash
   chmod +x cleanup-local-media.sh
   ```

2. Run the cleanup script:
   ```bash
   ./cleanup-local-media.sh
   ```

   This will delete all files from `/mnt/nvme/mediastack/library`

### Optional: Clean up completed torrents on the NAS

After migration, `library/downloads/qbittorrent/completed` on the NAS may contain items that Sonarr/Radarr have already moved to `tvshows`/`movies`, so you get the same content in two places.

1. Sync the whole library first and verify the stack works (as above).
2. When you’re ready to free space, review and clean up on the NAS:
   - Path on NAS: `/mnt/nas/mediastack/library/downloads/qbittorrent/completed`
   - Remove only what you’re sure is already in `movies/` or `tvshows/` (e.g. by date or by comparing filenames). Keep anything that’s still seeding or you want to keep as a duplicate.
3. Optionally do the same on the Pi **before** running `cleanup-local-media.sh` if you want to avoid copying then deleting that data.

No automated script is provided for this; do it manually or with your own checks to avoid deleting anything you need.

## Troubleshooting

### NAS Won't Mount

- Verify NAS IP and share name are correct
- Check network connectivity: `ping <NAS_IP>`
- Verify credentials are correct
- Check TrueNAS share permissions
- For SMB, ensure SMB service is running on TrueNAS
- For NFS, ensure NFS service is running and export is configured

### Services Can't Access NAS

- Verify NAS is mounted: `mountpoint /mnt/nas`
- Check permissions: `ls -la /mnt/nas/mediastack/library`
- Ensure user 1000:1000 has access: `sudo chown -R 1000:1000 /mnt/nas/mediastack`
- Check Docker container can see mount: `docker exec <container> ls /data`

### File Permissions Issues

If services can't write to NAS:
```bash
sudo chown -R 1000:1000 /mnt/nas/mediastack
sudo chmod -R 755 /mnt/nas/mediastack
```

### Auto-mount Not Working

- Check fstab entry: `cat /etc/fstab | grep nas`
- Test mount: `sudo mount -a`
- Check systemd logs: `journalctl -u mnt-nas-mediastack.mount` (if using systemd)

## Rollback Plan

If something goes wrong, you can rollback:

1. Stop services:
   ```bash
   docker-compose -f mediastack.yaml down
   ```

2. Revert `mediastack.yaml` to use `/mnt/nvme/mediastack/library`

3. Restart services:
   ```bash
   docker-compose -f mediastack.yaml up -d
   ```

## Notes

- The migration preserves file structure, permissions, and timestamps
- rsync is used for efficient incremental copying
- The cleanup script only removes files, not the directory structure
- Config files remain on the Pi (only media library moves to NAS)
