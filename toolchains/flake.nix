{
  description = "Buck2 + uv2nix project";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    buck2-nix = {
      url = "github:tweag/buck2.nix";
      flake = false;
    };

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    gomod2nix = {
      url = "github:nix-community/gomod2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      buck2-nix,
      pyproject-nix,
      uv2nix,
      pyproject-build-systems,
      gomod2nix,
      ...
    }:
    let
      lib = nixpkgs.lib;
      forAllSystems = lib.genAttrs lib.systems.flakeExposed;

      uv = import ./uv2nix.nix {
        inherit
          nixpkgs
          pyproject-nix
          uv2nix
          pyproject-build-systems
          ;
      };

      go = import ./gomod2nix.nix {
        inherit nixpkgs gomod2nix;
      };
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          pythonSet = uv.pythonSets.${system}.overrideScope uv.editableOverlay;
          virtualenv = pythonSet.mkVirtualEnv "home" uv.workspace.deps.all;
        in
        {
          default = pkgs.mkShell {
            packages = [
              virtualenv
              pkgs.uv
              pkgs.buck2

              # Go toolchain
              pkgs.go
              go.goPackages.${system}.gomod2nix
              self.packages.${system}.go-schema-kcl
              self.packages.${system}.python-crd-cloudcoil

              pkgs.kpt
              pkgs.kcl
            ];

            env = {
              UV_NO_SYNC = "1";
              UV_PYTHON = pythonSet.python.interpreter;
              UV_PYTHON_DOWNLOADS = "never";
            };

            shellHook = ''
              unset PYTHONPATH
              export REPO_ROOT=$(git rev-parse --show-toplevel)

              mkdir -p .buckconfig.d
              cat > .buckconfig.d/buck2-nix.config <<'EOS'
              [external_cell_nix]
                git_origin = https://github.com/tweag/buck2.nix.git
                commit_hash = ${buck2-nix.rev}
              EOS

              echo building python
              #buck2 build root//schemas/crds:generated_python --out tests/generated

              echo building kcl
              #buck2 build root//schemas/crds:generated_kcl --out schemas/kcl

              xonsh
            '';
          };
        }
      );

      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          pythonSet = uv.pythonSets.${system};
          pythonSetWithEditables = pythonSet.overrideScope uv.editableOverlay;

          # Recreate the SAME locked env the devShell uses
          virtualenv = pythonSetWithEditables.mkVirtualEnv "python-crd-cloudcoil-env" uv.workspace.deps.all;
        in
        {
          default = pythonSet.mkVirtualEnv "env" uv.workspace.deps.default;

          go-schema-kcl = go.buildGoBinary {
            inherit system;
            pname = "go-schema-kcl";
          };

          python-crd-cloudcoil = pkgs.stdenv.mkDerivation {
            pname = "python-crd-cloudcoil";
            version = "0.1.0";

            src = ./codegen_scripts/python-crd-cloudcoil;
            dontUnpack = true;

            installPhase = ''
              mkdir -p $out/bin
              mkdir -p $out/lib/python-crd-cloudcoil

              # Copy code + templates
              cp -r $src/* $out/lib/python-crd-cloudcoil/

              # Wrapper that runs inside the uv2nix venv
              cat > $out/bin/python-crd-cloudcoil <<EOF
              #!${pkgs.runtimeShell}
              exec ${virtualenv}/bin/python \
                $out/lib/python-crd-cloudcoil/main.py "\$@"
              EOF

              chmod +x $out/bin/python-crd-cloudcoil
            '';
          };

          ruff = pkgs.ruff;
          kcl = pkgs.kcl;
        }
      );

    };
}
