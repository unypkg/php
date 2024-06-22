#!/usr/bin/env bash
# shellcheck disable=SC2034,SC1091,SC2154

set -vx

######################################################################################################################
### Setup Build System and GitHub

apt install -y pkg-config build-essential autoconf bison re2c \
    libxml2-dev

wget -qO- uny.nu/pkg | bash -s buildsys

### Installing build dependencies
unyp install openssl/1.1.1w re2c icu/68 curl libpng libwebp libjpeg-turbo freetype libgd imagemagick \
    pcre2 libxml2 libxslt libexif libzip oniguruma argon2

### Getting Variables from files
UNY_AUTO_PAT="$(cat UNY_AUTO_PAT)"
export UNY_AUTO_PAT
GH_TOKEN="$(cat GH_TOKEN)"
export GH_TOKEN

source /uny/git/unypkg/fn
uny_auto_github_conf

######################################################################################################################
### Timestamp & Download

uny_build_date

mkdir -pv /uny/sources
cd /uny/sources || exit

pkgname="php"
pkggit="https://github.com/php/php-src.git refs/tags/php-7.4*"
gitdepth="--depth=1"

### Get version info from git remote
# shellcheck disable=SC2086
latest_head="$(git ls-remote --refs --tags --sort="v:refname" $pkggit | grep -E "php-7.4[0-9.]*$" | tail --lines=1)"
latest_ver="$(echo "$latest_head" | grep -o "php-[0-9.]*" | sed "s|php-||")"
latest_commit_id="$(echo "$latest_head" | cut --fields=1)"

version_details

# Release package no matter what:
echo "newer" >release-"$pkgname"

git_clone_source_repo

cd php-src || exit

# Downloading external extensions
declare -a extensions=("imagick" "redis")
for ext in "${extensions[@]}"; do
    wget -O "$ext".tgz https://pecl.php.net/get/"$ext"
    mkdir -p ext/"$ext"
    tar -zxf "$ext".tgz --strip-components=1 -C ext/"$ext"/
    rm "$ext".tgz
done

cd /uny/sources || exit

ls -lah
mv -v php-src php
pkg_git_repo_dir="php"

version_details
archiving_source

######################################################################################################################
### Build

# unyc - run commands in uny's chroot environment
# shellcheck disable=SC2154
unyc <<"UNYEOF"
set -vx
source /uny/git/unypkg/fn

pkgname="php"

version_verbose_log_clean_unpack_cd
get_env_var_values
get_include_paths

####################################################
### Start of individual build script

#unset LD_RUN_PATH

./buildconf --force

readline_dir=(/uny/pkg/readline/*)
bzip2_dir=(/uny/pkg/bzip2/*)
argon2_dir=(/uny/pkg/argon2/*)
imagick_dir=(/uny/pkg/imagemagick/*)

./configure \
    --prefix=/uny/pkg/"$pkgname"/"$pkgver" \
    --enable-litespeed \
    --enable-fpm \
    --with-fpm-user=unyweb \
    --with-fpm-group=unyweb \
    --with-config-file-path=/etc/uny \
    --with-gettext \
    --with-readline="${readline_dir[0]}" \
    --disable-cgi \
    --disable-phpdbg \
    --enable-sockets \
    --without-sqlite3 \
    --without-pdo-sqlite \
    --with-mysqli \
    --with-mysql-sock=/run/mysqld/mysqld.sock \
    --with-pdo-mysql \
    --enable-ctype \
    --with-openssl \
    --with-curl \
    --enable-exif \
    --enable-mbstring \
    --with-zip \
    --with-bz2="${bzip2_dir[0]}" \
    --enable-bcmath \
    --with-jpeg \
    --with-webp \
    --enable-intl \
    --enable-pcntl \
    --with-gmp \
    --with-password-argon2="${argon2_dir[0]}" \
    --with-zlib \
    --with-freetype \
    --enable-soap \
    --enable-gd \
    --with-imagick="${imagick_dir[0]}" \
    --enable-redis=shared

make -j"$(nproc)"

make install

####################################################
### End of individual build script

add_to_paths_files
dependencies_file_and_unset_vars
cleanup_verbose_off_timing_end
UNYEOF

######################################################################################################################
### Packaging

package_unypkg
