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

```bash
# For macOS
brew install pkg-config
brew install glfw3 pkg-config
brew install sdl2
brew install glew

# For Ubuntu
sudo apt-get install pkg-config libsdl2-dev libglew-dev

# For Fedora
sudo dnf install gcc-c++
sudo dnf install SDL2-devel
sudo dnf install glew-devel

# For Windows 11
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
