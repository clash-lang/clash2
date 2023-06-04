# This overlay contains everything which is non-specific to the version of GHC
# used. Since it is applied to nixpkgs, we also import and apply the more
# specific overlay for the version of GHC in `compilerVersion`.

{ ghc-tcplugins-extra
, ghc-typelits-extra
, ghc-typelits-knownnat
, ghc-typelits-natnormalise
}:
compilerVersion:
next: prev:
let
  # An overlay with the things we need to change for the specified GHC version.
  ghcOverlay = import (./. + "/overlay-${compilerVersion}.nix") {
    pkgs = prev;
  };

  # An overlay with the packages we pull in as inputs to this flake.
  #
  # This is mostly intended for packages developed by QBayLogic which are
  # standalone repositories, e.g. the typechecker plugins needed for Clash.
  haskellExternalPackages =
    hnext: hprev: {
      ghc-tcplugins-extra =
        hprev.callCabal2nix
          "ghc-tcplugins-extra"
          "${ghc-tcplugins-extra}"
          {};

      ghc-typelits-extra =
        hprev.callCabal2nix
          "ghc-typelits-extra"
          "${ghc-typelits-extra}"
          {};

      ghc-typelits-knownnat =
        hprev.callCabal2nix
          "ghc-typelits-knownnat"
          "${ghc-typelits-knownnat}"
          {};

      ghc-typelits-natnormalise =
        hprev.callCabal2nix
          "ghc-typelits-natnormalise"
          "${ghc-typelits-natnormalise}"
          {};
    };

  # An overlay with the packages in this repository.
  haskellInternalPackages =
    # Might be able to replace rec with use of hfinal?
    hnext: hprev: rec {
      clash-benchmark =
        let
          unmodified = hprev.callCabal2nix "clash-benchmark" ../benchmark {
            inherit clash-ghc clash-lib clash-prelude;
          };
        in
        unmodified.overrideAttrs (old: {
          buildInputs = (old.buildInputs or []) ++ [
            prev.makeWrapper
          ];

          postInstall = (old.postInstall or "") + ''
            wrapProgram $out/bin/clash-benchmark-concurrency \
              --prefix PATH : ${dirOf "${old.passthru.env.NIX_GHC}"} \
              --set GHC_PACKAGE_PATH "${old.passthru.env.NIX_GHC_LIBDIR}/package.conf.d:"

            wrapProgram $out/bin/clash-benchmark-normalization \
              --prefix PATH : ${dirOf "${old.passthru.env.NIX_GHC}"} \
              --set GHC_PACKAGE_PATH "${old.passthru.env.NIX_GHC_LIBDIR}/package.conf.d:"
          '';
        });

      clash-cores =
        hprev.callCabal2nixWithOptions "clash-cores" ../clash-cores "--flag nix" {
          inherit clash-prelude;
        };

      clash-cosim =
        let
          unmodified =
            hprev.callCabal2nix "clash-cosim" ../clash-cosim {
              inherit clash-prelude;
            };
        in
        unmodified.overrideAttrs (old: {
          nativeBuildInputs = (old.nativeBuildInputs or []) ++ [
            prev.verilog
          ];
        });

      clash-ffi =
        hprev.callCabal2nix "clash-ffi" ../clash-ffi {
          inherit clash-prelude;
        };

      clash-ghc =
        let
          unmodified =
            hprev.callCabal2nix "clash-ghc" ../clash-ghc {
              inherit clash-lib clash-prelude;
            };
        in
        prev.haskell.lib.enableSharedExecutables
          (unmodified.overrideAttrs (old: {
            buildInputs = (old.buildInputs or []) ++ [
              prev.makeWrapper
            ];

            postInstall = (old.postInstall or "") + ''
              wrapProgram $out/bin/clash \
                --prefix PATH : ${dirOf "${old.passthru.env.NIX_GHC}"} \
                --set GHC_PACKAGE_PATH "${old.passthru.env.NIX_GHC_LIBDIR}/package.conf.d:"

              wrapProgram $out/bin/clashi \
                --prefix PATH : ${dirOf "${old.passthru.env.NIX_GHC}"} \
                --set GHC_PACKAGE_PATH "${old.passthru.env.NIX_GHC_LIBDIR}/package.conf.d:"
            '';
          }));

      clash-lib =
        hprev.callCabal2nix "clash-lib" ../clash-lib {
          inherit clash-prelude;
        };

      clash-lib-hedgehog =
        hprev.callCabal2nix "clash-lib-hedgehog" ../clash-lib-hedgehog {
          inherit clash-lib;
        };

      clash-prelude =
        hprev.callCabal2nixWithOptions
          "clash-prelude"
          ../clash-prelude
          "--flag workaround-ghc-mmap-crash"
          {};

      clash-prelude-hedgehog =
        hprev.callCabal2nix "clash-prelude-hedgehog" ../clash-prelude-hedgehog {
          inherit clash-prelude;
        };

      clash-profiling =
        hprev.callCabal2nix "clash-profiling" ../benchmark/profiling/run {
          inherit
            clash-benchmark
            clash-ghc
            clash-lib
            clash-prelude
            clash-profiling-prepare;
        };

      clash-profiling-prepare =
        let
          unmodified =
            hprev.callCabal2nix "clash-profiling-prepare" ../benchmark/profiling/prepare {
              inherit clash-benchmark clash-lib clash-prelude;
            };
        in
        unmodified.overrideAttrs (old: {
          buildInputs = (old.buildInputs or []) ++ [
            prev.makeWrapper
          ];

          postInstall = (old.postInstall or "") + ''
            wrapProgram $out/bin/clash-profile-netlist-prepare \
              --prefix PATH : ${dirOf "${old.passthru.env.NIX_GHC}"} \
              --set GHC_PACKAGE_PATH "${old.passthru.env.NIX_GHC_LIBDIR}/package.conf.d:"

            wrapProgram $out/bin/clash-profile-normalization-prepare \
              --prefix PATH : ${dirOf "${old.passthru.env.NIX_GHC}"} \
              --set GHC_PACKAGE_PATH "${old.passthru.env.NIX_GHC_LIBDIR}/package.conf.d:"
          '';
        });

      clash-term =
        hprev.callCabal2nix "clash-term" ../clash-term {
          inherit clash-lib;
        };

      clash-testsuite =
        let
          unmodified =
            hprev.callCabal2nix "clash-testsuite" ../tests {
              inherit clash-cores clash-ghc clash-lib clash-prelude;
            };
        in
        unmodified.overrideAttrs (old: {
          buildInputs = (old.buildInputs or []) ++ [
            prev.makeWrapper
          ];

          postInstall = (old.postInstall or "") + ''
            wrapProgram $out/bin/clash-testsuite \
              --add-flags "--no-modelsim --no-vivado" \
              --prefix PATH : ${dirOf "${old.passthru.env.NIX_GHC}"} \
              --set GHC_PACKAGE_PATH "${old.passthru.env.NIX_GHC_LIBDIR}/package.conf.d:" \
              --prefix PATH : ${prev.lib.makeBinPath [
                prev.gcc
                prev.ghdl-llvm
                prev.symbiyosys
                prev.verilator
                prev.verilog
                prev.yosys
              ]} \
              --set LIBRARY_PATH ${prev.lib.makeLibraryPath [
                prev.ghdl-llvm
                prev.zlib.static
              ]}
          '';
        });
    };

  haskellOverlays =
    prev.lib.composeManyExtensions [
      ghcOverlay
      haskellExternalPackages
      haskellInternalPackages
    ];
in
{
  "clashPackages-${compilerVersion}" =
    prev.haskell.packages.${compilerVersion}.extend haskellOverlays;
}
