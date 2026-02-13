# Changelog

All notable changes to the HaskellLSP project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial HaskellLSP Language Server Protocol implementation
- Core LSP server with JSON-RPC communication
- Document synchronization with incremental updates
- Syntax and semantic diagnostics
- Code completion with type information and module-qualified suggestions
- Hover information showing type signatures and documentation
- Go-to-definition functionality
- Document symbols and outline view
- Configuration management with hot-reload support
- VSCode extension with automatic server lifecycle management
- Crash recovery with exponential backoff
- Comprehensive test suite with property-based testing
- Docker support for containerized deployment
- Build automation with Stack and Make

### Core Features
- **LSP Server (Haskell)**
  - JSON-RPC protocol implementation with proper Content-Length headers
  - Document state management and version tracking
  - Error handling with recovery strategies
  - Configurable logging levels (Debug, Info, Warning, Error)
  - Multi-threaded server with STM-based state management

- **Language Features**
  - Document synchronization (open/close/change/save)
  - Real-time diagnostics with syntax and type error reporting
  - Intelligent code completion with trigger characters
  - Hover information with type signatures and documentation
  - Go-to-definition navigation
  - Document symbols for outline view
  - Configuration synchronization

- **VSCode Extension (TypeScript)**
  - Automatic server discovery and lifecycle management
  - Configuration synchronization with real-time updates
  - Error handling with user-friendly messages
  - Automatic restart on server crashes (max 3 attempts)
  - Verbose logging support for debugging
  - Language configuration for Haskell files (.hs, .lhs)

### Architecture
- **Modular Design**
  - `LSP.Server`: Main server entry point and handler registration
  - `LSP.Types`: Core data types and JSON-RPC protocol helpers
  - `LSP.Diagnostics`: Error detection and reporting
  - `LSP.Error`: Error handling and recovery strategies
  - `Handlers.*`: Individual LSP request/notification handlers
  - `Analysis.Parser`: Haskell code parsing and symbol analysis

- **Handler Modules**
  - `Handlers.DocumentSync`: Document lifecycle management
  - `Handlers.Completion`: Code completion with context awareness
  - `Handlers.Hover`: Type information and documentation display
  - `Handlers.Definition`: Symbol definition navigation
  - `Handlers.Configuration`: Settings management and hot-reload

### Development Tools
- **Build System**
  - Stack with LTS 24.21 resolver and GHC 9.10.3
  - Makefile with optimized build targets
  - Fast development builds with `--fast` flag
  - Parallel builds with `-j4` and increased heap size

- **Testing Framework**
  - Hspec for behavior-driven testing
  - QuickCheck for property-based testing
  - Doctest for documentation testing
  - Comprehensive test coverage for all handlers

- **Code Quality**
  - Stylish-Haskell formatting with project configuration
  - GHCid for fast feedback during development
  - Wall warnings enabled with optimization flags
  - Haddock documentation generation

- **Docker Support**
  - Multi-stage Dockerfile for optimized images
  - Docker Compose configuration for development
  - Automated build and deployment scripts

### Configuration
- **Server Configuration**
  - Configurable log levels and file output
  - Worker thread pool configuration
  - Error recovery settings with retry policies
  - Document state management options

- **VSCode Extension Settings**
  - `haskellLsp.serverPath`: Custom server executable path
  - `haskellLsp.logLevel`: Server logging verbosity
  - `haskellLsp.maxRestartCount`: Crash recovery limits
  - `haskellLsp.enableVerboseLogging`: Debug output control

### Dependencies
- **Core Libraries**
  - `lsp` and `lsp-types`: Language Server Protocol implementation
  - `co-log-core`: Structured logging framework
  - `mtl`: Monad transformer library for effect management
  - `text`: Efficient Unicode text processing
  - `containers`: Standard data structures
  - `prettyprinter`: Pretty printing utilities

- **Development Dependencies**
  - `hspec`: Testing framework
  - `QuickCheck`: Property-based testing
  - `doctest`: Documentation testing
  - `ghc-lib-parser`: Haskell parsing capabilities

### Build Targets
- `make build`: Optimized production build
- `make test`: Run complete test suite
- `make watch-test`: Continuous testing during development
- `make ghcid`: Interactive development with fast feedback
- `make format`: Code formatting with stylish-haskell
- `make docker-build`: Container image creation
- `make build-all`: Build both server and VSCode extension
- `make install-extension`: Install VSCode extension locally

## [0.1.0.0] - 2024-12-13

### Added
- Initial project setup with Stack and Cabal configuration
- Basic project structure with src/, app/, and test/ directories
- License (BSD-3-Clause) and copyright information
- README with comprehensive documentation
- Development tooling setup (ghcid, stylish-haskell)

### Project Metadata
- **Author**: Mingyu Choo (mingyuchoo@gmail.com)
- **License**: BSD-3-Clause
- **Repository**: https://github.com/mingyuchoo/HaskellLSP
- **Language**: Haskell with GHC2024 standard
- **Build System**: Stack with LTS 24.21

---

## Version History Summary

- **v0.1.0.0**: Initial project setup and foundation
- **Unreleased**: Full LSP implementation with VSCode extension

## Contributing

When contributing to this project, please:

1. Follow the existing code style (use `make format`)
2. Add tests for new functionality
3. Update this CHANGELOG with your changes
4. Ensure all tests pass with `make test`
5. Update documentation as needed

## Links

- [Repository](https://github.com/mingyuchoo/HaskellLSP)
- [Issues](https://github.com/mingyuchoo/HaskellLSP/issues)
- [Language Server Protocol Specification](https://microsoft.github.io/language-server-protocol/)