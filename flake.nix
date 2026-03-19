{
  description = "Martin - MapLibre tile server";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs =
    {
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };

        martinSrc = pkgs.fetchFromGitHub {
          owner = "maplibre";
          repo = "martin";
          rev = "7c676af35948ceb4efa9b82e667dab3335186742";
          hash = "sha256-wThCAR3SL454HyHAqbfGfUESPVTiOUMQDq37O/bjJbI=";
        };

        # Build the web UI separately so we avoid running npm inside the Rust
        # sandbox (where /usr/bin/env and network are unavailable).
        martin-ui = pkgs.buildNpmPackage {
          pname = "martin-ui";
          version = "1.4.0";
          src = "${martinSrc}/martin/martin-ui";
          npmDepsHash = "sha256-ay8r+gvUVzza0GeJvrmtaEvppIc4wWjrqPGrK8oT+lA=";

          postPatch = ''
            # favicon.ico is a cross-directory symlink; replace with the real file
            rm public/_/assets/favicon.ico
            cp ${martinSrc}/demo/frontend/public/favicon.ico public/_/assets/favicon.ico
          '';

          installPhase = ''
            runHook preInstall
            cp -r dist $out
            runHook postInstall
          '';
        };

        martin = pkgs.rustPlatform.buildRustPackage {
          pname = "martin";
          version = "1.4.0";

          src = martinSrc;

          cargoHash = "sha256-6hPZ3Db6ezPmtBT4XClERiV+MCFZgNLTnZTOeCgRln8=";

          postPatch = ''
            # Provide the pre-built UI where build.rs expects it
            cp -r ${martin-ui} martin/martin-ui/dist

            # Replace build.rs with a version that embeds the pre-built dist
            # directly instead of running npm install + npm run build.
            cat > martin/build.rs << 'EOF'
#[cfg(feature = "webui")]
fn webui() {
    let dist = std::env::current_dir()
        .expect("Unable to get current dir")
        .join("martin-ui/dist");

    static_files::resource_dir(&dist)
        .build()
        .expect("failed to embed webui");

    println!("cargo:rerun-if-changed={}", dist.display());
}

fn main() {
    #[cfg(feature = "webui")]
    if option_env!("RUSTDOC").is_none() && option_env!("DOCS_RS").is_none() {
        webui();
    }
}
EOF
          '';

          nativeBuildInputs = with pkgs; [
            pkg-config
          ];

          buildInputs = with pkgs; [
            openssl
            postgresql
            sqlite
          ];

          doCheck = false;

          meta = with pkgs.lib; {
            description = "Blazing fast and lightweight PostGIS, MBTiles and GeoPackage tile server";
            homepage = "https://maplibre.org/martin/";
            license = licenses.asl20;
            mainProgram = "martin";
          };
        };
      in
      {
        packages = {
          inherit martin;
          default = martin;
        };

        devShells.default = pkgs.mkShell {
          packages = [ martin ];
        };
      }
    );
}
