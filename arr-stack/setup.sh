#!/usr/bin/env bash
set -e

echo "----- prowlarr/sonarr/radarr/qbitorrent/gluetun stack setup -----"

# Ask for basic settings
read -rp "Mullvad account number: " MULLVAD_ACCOUNT
read -rp "Timezone (e.g. America/New_York): " TZ
TZ=${TZ:-America/New_York}

read -rp "PUID (default 1000): " PUID
PUID=${PUID:-1000}
read -rp "PGID (default 1000): " PGID
PGID=${PGID:-1000}

echo
echo "Now choose where to store data on the host."
read -rp "Base directory for app configs (e.g. /srv/arr/configs or ./config): " CONFIG_ROOT
CONFIG_ROOT=${CONFIG_ROOT:-./config}

read -rp "Downloads directory (e.g. /srv/arr/downloads or ./downloads): " DOWNLOADS_DIR
DOWNLOADS_DIR=${DOWNLOADS_DIR:-./downloads}

read -rp "TV library directory (e.g. /srv/media/tv or ./media/tv): " TV_DIR
TV_DIR=${TV_DIR:-./media/tv}

read -rp "Movies library directory (e.g. /srv/media/movies or ./media/movies): " MOVIES_DIR
MOVIES_DIR=${MOVIES_DIR:-./media/movies}

echo
echo "Creating directories if they do not exist..."
mkdir -p \
  "$CONFIG_ROOT/gluetun" \
  "$CONFIG_ROOT/qbittorrent" \
  "$CONFIG_ROOT/sonarr" \
  "$CONFIG_ROOT/radarr" \
  "$CONFIG_ROOT/prowlarr" \
  "$DOWNLOADS_DIR" \
  "$TV_DIR" \
  "$MOVIES_DIR"

echo
echo "Writing .env file..."
cat > .env <<EOF
MULLVAD_ACCOUNT=${MULLVAD_ACCOUNT}
VPN_PASSWORD=m
TZ=${TZ}
PUID=${PUID}
PGID=${PGID}

CONFIG_ROOT=${CONFIG_ROOT}
DOWNLOADS_DIR=${DOWNLOADS_DIR}
TV_DIR=${TV_DIR}
MOVIES_DIR=${MOVIES_DIR}
EOF

echo "Writing docker-compose.yml..."
cat > docker-compose.yml <<'EOF'
version: "3.8"

services:
  gluetun:
    image: qmcgaw/gluetun:latest
    container_name: gluetun
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    environment:
      - VPN_SERVICE_PROVIDER=mullvad
      - VPN_TYPE=openvpn
      - OPENVPN_USER=${MULLVAD_ACCOUNT}
      - OPENVPN_PASSWORD=${VPN_PASSWORD}
      - HEALTH_VPN_DURATION_INITIAL=30s
      - HEALTH_VPN_DURATION_ADDITION=10s
      - TZ=${TZ}
    volumes:
      - ${CONFIG_ROOT}/gluetun:/gluetun
    ports:
      - 8080:8080   # qBittorrent
      - 8989:8989   # Sonarr
      - 7878:7878   # Radarr
      - 6881:6881
      - 6881:6881/udp
      - 9696:9696   # Prowlarr
    restart: unless-stopped

  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent:latest
    container_name: qbittorrent
    network_mode: "service:gluetun"
    depends_on:
      - gluetun
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
      - WEBUI_PORT=8080
    volumes:
      - ${CONFIG_ROOT}/qbittorrent:/config
      - ${DOWNLOADS_DIR}:/downloads
    restart: unless-stopped

  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: sonarr
    network_mode: "service:gluetun"
    depends_on:
      - qbittorrent
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
    volumes:
      - ${CONFIG_ROOT}/sonarr:/config
      - ${TV_DIR}:/tv
      - ${DOWNLOADS_DIR}:/downloads
    restart: unless-stopped

  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    network_mode: "service:gluetun"
    depends_on:
      - qbittorrent
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
    volumes:
      - ${CONFIG_ROOT}/radarr:/config
      - ${MOVIES_DIR}:/movies
      - ${DOWNLOADS_DIR}:/downloads
    restart: unless-stopped

  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    container_name: prowlarr
    network_mode: "service:gluetun"
    depends_on:
      - gluetun
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
    volumes:
      - ${CONFIG_ROOT}/prowlarr:/config
    restart: unless-stopped
EOF

echo
echo "Done."
echo "You can now start the stack with:"
echo "  docker compose up -d"
EOF
