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
    let
      # Overlay that adds martin to any nixpkgs instance.
      # Consumers can apply this to their own nixpkgs:
      #
      #   nixpkgs.overlays = [ martin-flake.overlays.default ];
      overlay =
        final: _prev:
        let
          martinSrc = final.fetchFromGitHub {
            owner = "maplibre";
            repo = "martin";
            rev = "martin-v1.5.0";
            hash = "sha256-WW9UegVaY3svtdYU4Q1CCwdxH7gQjbNrLxJ3pKujEYU=";
          };

          # Build the web UI separately so we avoid running npm inside the Rust
          # sandbox (where /usr/bin/env and network are unavailable).
          martin-ui = final.buildNpmPackage {
            pname = "martin-ui";
            version =
              (builtins.fromJSON (builtins.readFile "${martinSrc}/martin/martin-ui/package.json")).version;
            src = "${martinSrc}/martin/martin-ui";
            npmDepsHash = "sha256-dThyFLFC4oact0yygYVFXomKw0ldk7F1tX+1/qrlU7I=";

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
        in
        {
          martin = final.rustPlatform.buildRustPackage {
            pname = "martin";
            version = (fromTOML (builtins.readFile "${martinSrc}/martin/Cargo.toml")).package.version;

            src = martinSrc;

            cargoHash = "sha256-/BpW6OrhDRRHmlrDOtxLVepx+Iifyzi2TVcILNFhSYY=";

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

            nativeBuildInputs = with final; [
              pkg-config
            ];

            buildInputs = with final; [
              openssl
              postgresql
              sqlite
            ];

            doCheck = false;

            meta = with final.lib; {
              description = "Blazing fast and lightweight PostGIS, MBTiles and GeoPackage tile server";
              homepage = "https://maplibre.org/martin/";
              license = licenses.asl20;
              mainProgram = "martin";
            };
          };
        };
    in
    {
      overlays.default = overlay;
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
      in
      {
        packages = {
          inherit (pkgs) martin;
          default = pkgs.martin;
        };

        devShells.default = pkgs.mkShell {
          packages = [ pkgs.martin ];
        };
      }
    );
}
