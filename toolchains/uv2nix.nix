{
  nixpkgs,
  pyproject-nix,
  uv2nix,
  pyproject-build-systems,
}:

let
  lib = nixpkgs.lib;
  forAllSystems = lib.genAttrs lib.systems.flakeExposed;

  # Load workspace from toolchains/
  workspace = uv2nix.lib.workspace.loadWorkspace {
    workspaceRoot = ./venv;
  };

  overlay = workspace.mkPyprojectOverlay {
    sourcePreference = "wheel";
  };

  editableOverlay = workspace.mkEditablePyprojectOverlay {
    root = "$REPO_ROOT";
  };

  pythonSets = forAllSystems (
    system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
      python = pkgs.python3;
    in
    (pkgs.callPackage pyproject-nix.build.packages {
      inherit python;
    }).overrideScope
      (
        lib.composeManyExtensions [
          pyproject-build-systems.overlays.wheel
          overlay
        ]
      )
  );
in
{
  inherit
    workspace
    overlay
    editableOverlay
    pythonSets
    ;
}
