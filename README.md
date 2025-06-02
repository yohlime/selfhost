# Home Server Setup

## Description

This repository contains the Docker Compose configuration for my home server.

## Services

- **Caddy:** Reverse proxy and automatic SSL certificate manager. Handles routing and securing access to all other services.
- **Homer:** Simple static homepage to provide links to all the services.
- **Pi-hole:** Network-wide ad blocker and DNS server. Also uses Unbound for DNS resolution.
- **Syncthing:** Continuous file synchronization program for syncing files between devices.
- **Photoprism:** AI-powered photo management solution for browsing, organizing, and sharing photos.
- **Vaultwarden:** Lightweight Bitwarden-compatible password manager.
- **Uptime Kuma:** Self-hosted uptime monitoring tool.
- **OpenWebUI:** A web UI for interacting with large language models.
- **LiteLLM:** A unified interface for calling different LLMs.
