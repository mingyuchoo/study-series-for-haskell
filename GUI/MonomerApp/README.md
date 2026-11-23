# Monomer starter application

Starter application for the Monomer library, including:

- Dependencies
- Model and events type
- Event handler
- UI builder

For more information, check https://github.com/fjvallarino/monomer.

## Create a new project

```bash
git clone https://github.com/fjvallarino/MonomerApp.git <your-app-name>
```

## Prerequisites

### macOS

```bash
brew install pkg-config
brew install glfw3 pkg-config
brew install sdl2
brew install glew
```

### Ubuntu

```bash
sudo apt-get install pkg-config libsdl2-dev libglew-dev
```

### Fedora

```bash
sudo dnf install gcc-c++
sudo dnf install SDL2-devel
sudo dnf install glew-devel
```

### Windows 11

```bash
stack setup
stack exec -- pacman -S msys2-keyring
stack exec -- pacman -S mingw-w64-x86_64-pkg-config
stack exec -- pacman -S mingw-w64-x86_64-SDL2
stack exec -- pacman -S mingw-w64-x86_64-freeglut
stack exec -- pacman -S mingw-w64-x86_64-glew
stack exec -- pacman -S mingw-w64-x86_64-freetype
stack exec -- pacman -Syu
```

## References

- https://github.com/fjvallarino/monomer/blob/main/docs/tutorials/00-setup.md
