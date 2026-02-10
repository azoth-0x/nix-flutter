{
  description = "Flutter mobile dev shell (Android SDK + Flutter)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            android_sdk.accept_license = true;
          };
        };

        flutter = pkgs.flutter;

        androidComposition = pkgs.androidenv.composeAndroidPackages {
          cmdLineToolsVersion = "9.0";
          platformVersions = [ "36" "35" "34" ];
          buildToolsVersions = [ "36.0.0" "35.0.0" "34.0.0" "28.0.3" ];

          includeNDK = true;
          ndkVersions = [ "28.2.13676358" ];

          includeCmake = true;
          cmakeVersions = [ "3.22.1" ];

          includeEmulator = false;
          includeSystemImages = false;

          extraLicenses = [
            "android-sdk-license"
            "android-sdk-preview-license"
            "google-gdk-license"
          ];
        };

        androidSdk = androidComposition.androidsdk;
        jdk = pkgs.jdk17;
        sdkRootStore = "${androidSdk}/libexec/android-sdk";
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            flutter
            androidSdk
            jdk
            gradle
            git
            unzip
          ];

          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
            pkgs.vulkan-loader
            pkgs.libGL
          ];

          shellHook = ''
            export NIX_ANDROID_SDK="${sdkRootStore}"
            export ANDROID_SDK_ROOT="$NIX_ANDROID_SDK"
            export ANDROID_HOME="$NIX_ANDROID_SDK"
            export JAVA_HOME="${jdk.home}"
            unset FLUTTER_LOCAL_ENGINE_HOST
            unset FLUTTER_LOCAL_ENGINE
            export FLUTTER_LOCAL_ENGINE_HOST=""
            export FLUTTER_LOCAL_ENGINE=""

            CLT_DIR="$(ls -d "$NIX_ANDROID_SDK"/cmdline-tools/* 2>/dev/null | head -n1 || true)"
            export PATH="$NIX_ANDROID_SDK/platform-tools:''${CLT_DIR:+$CLT_DIR/bin}:$PATH"

            BT_DIR="$(ls -d "$NIX_ANDROID_SDK"/build-tools/* 2>/dev/null | sort -V | tail -n1 || true)"
            if [ -n "$BT_DIR" ] && [ -x "$BT_DIR/aapt2" ]; then
              export GRADLE_OPTS="-Dorg.gradle.project.android.aapt2FromMavenOverride=$BT_DIR/aapt2 ''${GRADLE_OPTS:-}"
            fi

            flutter config --android-sdk "$NIX_ANDROID_SDK" >/dev/null 2>&1 || true

            echo "ANDROID_SDK_ROOT=$NIX_ANDROID_SDK"
            echo "cmdline-tools -> $CLT_DIR"
          '';
        };
      });
}
