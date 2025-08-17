# Media Server Stack

A complete Docker Compose setup for a media server with VPN protection, automated media management, and streaming capabilities.

## Services Included

- **VPN & Download Management**: gluetun (AirVPN/WireGuard), qBittorrent, NZBGet
- **Media Management**: Sonarr, Radarr, Lidarr, Bazarr, Prowlarr
- **Media Server**: Plex
- **Management Tools**: Overseerr, Tautulli
- **Health Monitoring**: deunhealth

## Prerequisites

- Docker and Docker Compose
- AirVPN account (or modify for your VPN provider)
- Plex account and claim token
- Raspberry Pi 5 or similar ARM64 device

## Configuration

This setup uses environment variables for sensitive configuration. You have two options:

### Option 1: Local .env file (Recommended for local use)
1. Copy `env.example` to `.env`:
   ```bash
   cp env.example .env
   ```
2. Edit `.env` with your actual values:
   ```bash
   # VPN Configuration (AirVPN/WireGuard)
   WIREGUARD_PRIVATE_KEY=your_actual_private_key
   WIREGUARD_PRESHARED_KEY=your_actual_preshared_key
   WIREGUARD_ADDRESSES=your_actual_vpn_ip
   
   # Plex Configuration
   PLEX_CLAIM=your_actual_plex_claim_token
   ```

### Option 2: GitHub Actions (For CI/CD)
Set these as GitHub repository secrets:
- `WIREGUARD_PRIVATE_KEY`
- `WIREGUARD_PRESHARED_KEY`
- `WIREGUARD_ADDRESSES`
- `PLEX_CLAIM`

## Getting Started

1. Clone this repository
2. Configure the sensitive values above
3. Create the required directories:
   ```bash
   sudo mkdir -p /docker/gluetun
   sudo mkdir -p /container/mediastack/config/{qbittorrent,nzbget,sonarr,radarr,lidarr,bazarr,plex,overseerr,tautulli,prowlarr}
   sudo mkdir -p /mnt/nvme/mediastack/library
   ```
4. Set proper permissions:
   ```bash
   sudo chown -R 1000:1000 /container/mediastack/config
   sudo chown -R 1000:1000 /mnt/nvme/mediastack/library
   ```
5. Start the stack:
   ```bash
   docker-compose -f mediastack.yaml up -d
   ```

## Ports

- **Plex**: 32400
- **Sonarr**: 8989
- **Radarr**: 7878
- **Lidarr**: 8686
- **Bazarr**: 6767
- **Overseerr**: 5055
- **Tautulli**: 8181
- **qBittorrent**: 8080 (via VPN)
- **NZBGet**: 6789 (via VPN)

## Network

All services run on a custom network (10.10.0.0/24) with VPN protection for download services.

## Security Notes

- VPN keys and Plex tokens are not included in this repository
- All sensitive data should be configured via environment variables
- Consider using Docker secrets for production deployments

## License

MIT License - feel free to use and modify as needed.
