# Maintainer: PapyElGringo <adrien@pesler.be>
pkgname=veshell-git
pkgver=0.2.0
pkgrel=1
pkgdesc="An innovative not-desktop environment for Linux made with modern technologies like Flutter and Rust."
arch=('x86_64' 'aarch64')
url="https://github.com/free-explorers/veshell"
license=('GPL3')
depends=(
  'fontconfig'
  'libseat.so'
  'libinput'
  'libxcb'
  'libxkbcommon'
  'mesa'
  'pixman'
  'systemd'
  'wayland'
)
makedepends=(
    'cargo' 
    'flutter-tool'
    'git'
)
source=("git+https://github.com/free-explorers/veshell.git")
sha256sums=('SKIP')

pkgver() {
  cd "${pkgname%-git}"
  git describe --long --tags | sed 's/\([^-]*-g\)/r\1/;s/-/./g'
}

build() {
  make
}

package() {
  make install DESTDIR="$pkgdir/"
}