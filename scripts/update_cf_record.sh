#!/bin/bash

# Load environment variables from .env file
if [ ! -f .env ]; then
  echo ".env file not found! Please create one with CF_API_TOKEN, ZONE_NAME, and ZONE_ID."
  exit 1
fi

# Export variables from .env into the environment
export $(grep -v '^#' .env | xargs)

# Validate required variables
if [[ -z "$CF_API_TOKEN" || -z "$ZONE_NAME" || -z "$ZONE_ID" ]]; then
  echo "One or more required environment variables (CF_API_TOKEN, ZONE_NAME, ZONE_ID) are missing in .env"
  exit 1
fi

RECORD_NAME_HOME="home.$ZONE_NAME"
RECORD_NAME_WILDCARD="*.home.$ZONE_NAME"

# Get Tailscale IP addresses on the VM
TAILSCALE_IP4=$(tailscale ip -4)
TAILSCALE_IP6=$(tailscale ip -6)

if [[ -z "$TAILSCALE_IP4" ]] && [[ -z "$TAILSCALE_IP6" ]]; then
  echo "Unable to detect Tailscale IP addresses."
  exit 1
fi

CF_API="https://api.cloudflare.com/client/v4"

update_record() {
  local TYPE=$1
  local NAME=$2
  local CONTENT=$3

  RECORD_ID=$(curl -s -X GET "$CF_API/zones/$ZONE_ID/dns_records?type=$TYPE&name=$NAME" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json" | jq -r '.result[0].id')

  if [[ "$RECORD_ID" == "null" ]]; then
    echo "Record $NAME ($TYPE) not found. Creating..."
    curl -s -X POST "$CF_API/zones/$ZONE_ID/dns_records" \
      -H "Authorization: Bearer $CF_API_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"$TYPE\",\"name\":\"$NAME\",\"content\":\"$CONTENT\",\"ttl\":120,\"proxied\":false}" | jq
  else
    echo "Updating $NAME ($TYPE) to $CONTENT"
    curl -s -X PUT "$CF_API/zones/$ZONE_ID/dns_records/$RECORD_ID" \
      -H "Authorization: Bearer $CF_API_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"$TYPE\",\"name\":\"$NAME\",\"content\":\"$CONTENT\",\"ttl\":120,\"proxied\":false}" | jq
  fi
}

if [[ -n "$TAILSCALE_IP4" ]]; then
  update_record "A" "$RECORD_NAME_HOME" "$TAILSCALE_IP4"
  update_record "A" "$RECORD_NAME_WILDCARD" "$TAILSCALE_IP4"
fi

if [[ -n "$TAILSCALE_IP6" ]]; then
  update_record "AAAA" "$RECORD_NAME_HOME" "$TAILSCALE_IP6"
  update_record "AAAA" "$RECORD_NAME_WILDCARD" "$TAILSCALE_IP6"
fi

echo "Cloudflare DNS update completed."

