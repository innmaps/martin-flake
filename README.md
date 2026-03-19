# martin-flake

A Nix flake that packages [Martin](https://maplibre.org/martin/), the blazing fast and lightweight MapLibre tile server supporting PostGIS, MBTiles, and GeoPackage sources.

## Usage

```bash
# Run martin directly
nix run github:munske/martin-flake

# Enter a dev shell with martin available
nix develop github:munske/martin-flake

# Add to your own flake
inputs.martin-flake.url = "github:munske/martin-flake";
```

## What's included

- **martin** v1.4.0 — built from source with the embedded web UI
- Supports PostgreSQL/PostGIS, MBTiles, and GeoPackage tile sources