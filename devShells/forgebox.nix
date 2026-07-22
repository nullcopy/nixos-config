{ pkgs, ... }:

let
  # CLI for the Keystone ForgeBox, packaged from source. Pinned to master
  # because upstream tags lag behind (package.json is at 1.2.0, newest tag
  # is v1.0.5). To bump: point rev at a newer commit, clear both hashes,
  # rebuild, and copy in the hashes Nix reports.
  forgebox-cli = pkgs.buildNpmPackage {
    pname = "forgebox-cli";
    version = "1.2.0";

    src = pkgs.fetchFromGitHub {
      owner = "KeystoneHQ";
      repo = "forgebox-cli";
      rev = "9b26ddebccb14a8eef970b3ad2c95952d21a8c91";
      hash = "sha256-LBe+CghXqhTLmoA5MddUhlKYZjeuNsw6mIdZeJUT5EE=";
    };

    npmDepsHash = "sha256-HZrOz0BorXKnkaAj0Ee5LEUPC2gcapjUrC028BYQRUc=";

    nativeBuildInputs = with pkgs; [
      python3
      pkg-config
    ];

    # The `usb` dependency ships glibc prebuilds that expect libudev under
    # /usr/lib; force node-gyp to compile it (and its bundled libusb) against
    # nix libs instead, so the rpath points into the store.
    buildInputs = with pkgs; [
      libusb1
      systemd
    ];
    npm_config_build_from_source = "true";
  };
in
pkgs.mkShell {
  packages = [ forgebox-cli ];
}
