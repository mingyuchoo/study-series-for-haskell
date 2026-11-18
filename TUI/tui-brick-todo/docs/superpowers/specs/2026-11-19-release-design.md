# Release scripts

Create native releases of the existing Stack project without changing its application architecture.

Both scripts format Haskell sources with Fourmolu, lint with HLint, build the executable and tests in release mode, run tests, stage only the executable, configuration examples, license and documentation, and package the result. Failures stop the pipeline. Package version comes from package.yaml and architecture from GHC, not the host shell.

Use native packaging tools: dpkg-deb with dpkg-shlibdeps and rpmbuild on Linux, pkgbuild and dylibbundler on macOS, and Inno Setup on Windows 11. Linux supports selecting deb, rpm or both; both is the default. Each operating system builds its own binaries. macOS bundles non-system dylibs; Windows recursively bundles non-system DLL imports. Linux packages declare runtime dependencies; its tarball targets compatible Linux systems.

Alternatives considered: fpm adds a Ruby dependency without removing platform-specific dependency handling; cross-compilation requires a separate toolchain and cannot validate native installers here. Native packaging follows the existing native Stack workflow.

Output defaults to dist/release and can be overridden. Artifacts are prepared in a temporary directory, checked, then atomically published as a complete tto-version-platform-architecture directory with SHA-256 checksums. Existing release directories are immutable; choose a different output path to rebuild the same version. Scripts do not install packages, launch the TUI, publish releases, sign with publisher credentials, or include user databases. macOS signing/notarization and Windows publisher signing remain release-operator tasks.

Tests exercise generated packages and archives using a compiled executable fixture while substituting the expensive Haskell toolchain at the process boundary. Real Stack build/tests and native Linux packaging are also verified. Other OS verification is reported separately.
