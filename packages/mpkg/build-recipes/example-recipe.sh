# mpkg Build Recipe — Example Package
# Place in /usr/share/mpkg/recipes/<pkgname>/recipe.sh

pkgname="example"
pkgver="1.0.0"
pkgdesc="An example package recipe for mpkg"
source_url="https://example.com/example-1.0.0.tar.gz"
depends="libc zlib"

build() {
    cd "$pkgname-$pkgver"
    ./configure \
        --prefix=/usr \
        --sysconfdir=/etc
    make -j$(nproc)
}

package() {
    cd "$pkgname-$pkgver"
    make install DESTDIR="$DESTDIR"
}
