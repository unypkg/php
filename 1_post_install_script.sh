#!/usr/bin/env bash
# shellcheck disable=SC2034,SC1091,SC2154,SC1003,SC2005

current_dir="$(pwd)"
unypkg_script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
unypkg_root_dir="$(cd -- "$unypkg_script_dir"/.. &>/dev/null && pwd)"

cd "$unypkg_root_dir" || exit

#############################################################################################
### Start of script

pkgver="$(basename "$unypkg_root_dir")"
small_pkgver="$(echo "$pkgver" | cut -d. -f1,2)"

mkdir -pv /uny/etc/php/"$pkgver"/php-fpm.d /etc/uny/php
ln -sfv /uny/etc/php/"$pkgver" /etc/uny/php

# 1. List only PHP directories starting with the specific minor version ($small_pkgver)
# We use "${small_pkgver}*" to match directories like 8.4, 8.4.7, 8.4.21, etc.
versions=$(find /uny/etc/php/ -mindepth 1 -maxdepth 1 -type d -name "${small_pkgver}*" -exec basename {} \; | sort -V)

# 2. Find the highest available version that is lower than the new $pkgver
for v in $versions; do
    # Stop the loop as soon as we reach the new version (or any higher version)
    if [[ "$v" == "$pkgver" ]]; then
        break
    fi
    # Keep updating target_ver with the closest previous version found so far
    target_ver="$v"
done

# 3. Only perform the copy operation if a valid predecessor version was found
if [[ -n "$target_ver" ]]; then
    src_dir="/uny/etc/php/$target_ver"
    echo "Closest version found: $target_ver. Copying structure to $pkgver..."

    # cp -a preserves attributes and copies recursively
    # -n (no-clobber) prevents overwriting already existing files in the target
    cp -an "$src_dir"/. /uny/etc/php/"$pkgver"/
fi

if [[ ! -f /uny/etc/php/"$pkgver"/php.ini ]]; then
    cp -a etc/php.ini-production /uny/etc/php/"$pkgver"/php.ini
fi
if [[ ! -f /uny/etc/php/"$pkgver"/php-fpm.conf ]]; then
    cp -a etc/php-fpm.conf.default /uny/etc/php/"$pkgver"/php-fpm.conf
fi

# Check if any .conf file exists using a safe array approach
conf_files=(/uny/etc/php/"$pkgver"/php-fpm.d/*.conf)
# If the first element doesn't exist as a file, the directory is empty of .conf files
if [[ ! -f "${conf_files[0]}" ]]; then
    cp -a etc/php-fpm.d/www.conf.default /uny/etc/php/"$pkgver"/php-fpm.d/www.conf
fi

# find etc -type f -print0 | while IFS= read -r -d '' filepath; do
#     rel_path="${filepath#etc/}" # Cuts off etc/
#     target="/uny/etc/php/$pkgver/$rel_path"

#     if [[ ! -f "$target" ]]; then
#         mkdir -p "$(dirname "$target")"
#         cp -a "$filepath" "$target"
#     fi
# done

cp -a etc/php-fpm.service /etc/systemd/system/uny-php"$small_pkgver"-fpm.service
#sed "s|.*Alias=.*||g" -i /etc/systemd/system/uny-mariadb.service
sed -e '/\[Install\]/a\' -e 'Alias=php'"$small_pkgver"'-fpm.service' -i /etc/systemd/system/uny-php"$small_pkgver"-fpm.service
sed -e '/\[Install\]/a\' -e 'Alias=php'"$(echo "$small_pkgver" | tr -d '.')"'.service' -i /etc/systemd/system/uny-php"$small_pkgver"-fpm.service
systemctl daemon-reload

#############################################################################################
### End of script

cd "$current_dir" || exit
