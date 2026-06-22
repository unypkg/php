#!/usr/bin/env bash
# shellcheck disable=SC2034,SC1091,SC2154,SC1003,SC2005

current_dir="$(pwd)"
unypkg_script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
unypkg_root_dir="$(cd -- "$unypkg_script_dir"/.. &>/dev/null && pwd)"

cd "$unypkg_root_dir" || exit

#############################################################################################
### Start of script

small_pkgver="$(basename "$unypkg_root_dir" | cut -d. -f1,2)"

mkdir -pv /uny/etc/php/"$small_pkgver"/php-fpm.d /etc/uny/php
ln -sfv /uny/etc/php/"$small_pkgver" /etc/uny/php

if [[ ! -f /uny/etc/php/"$small_pkgver"/php.ini ]]; then
    cp -a etc/php.ini-production /uny/etc/php/"$small_pkgver"/php.ini
fi
if [[ ! -f /uny/etc/php/"$small_pkgver"/php-fpm.conf ]]; then
    cp -a etc/php-fpm.conf.default /uny/etc/php/"$small_pkgver"/php-fpm.conf
fi

# Check if any .conf file exists using a safe array approach
conf_files=(/uny/etc/php/"$small_pkgver"/php-fpm.d/*.conf)
# If the first element doesn't exist as a file, the directory is empty of .conf files
if [[ ! -f "${conf_files[0]}" ]]; then
    cp -a etc/php-fpm.d/www.conf.default /uny/etc/php/"$small_pkgver"/php-fpm.d/www.conf
fi

# find etc -type f -print0 | while IFS= read -r -d '' filepath; do
#     rel_path="${filepath#etc/}" # Cuts off etc/
#     target="/uny/etc/php/$small_pkgver/$rel_path"

#     if [[ ! -f "$target" ]]; then
#         mkdir -p "$(dirname "$target")"
#         cp -a "$filepath" "$target"
#     fi
# done

# unyweb group
if ! getent group unyweb >/dev/null; then
    groupadd --system unyweb
fi

# unyphp FPM user in unyweb group, no home, nologin shell, system user
if ! getent passwd unyphp >/dev/null; then
    if ! useradd --system \
        --gid unyweb \
        --shell /bin/false \
        --no-create-home \
        --comment "PHP-FPM service user" \
        unyphp >/dev/null 2>&1; then
        echo "Failed to create user unyphp"
    fi
else
    # If the user exists but somehow dropped out of the group, fix it defensively
    if ! id -nG unyphp | grep -qw unyweb; then
        usermod -g unyweb unyphp
    fi
fi

chown -R unyphp:unyweb /uny/etc/php/"$small_pkgver"

cp -a etc/php-fpm.service /etc/systemd/system/uny-php"$small_pkgver"-fpm.service
#sed "s|.*Alias=.*||g" -i /etc/systemd/system/uny-mariadb.service
sed -e '/\[Install\]/a\' -e 'Alias=php'"$small_pkgver"'-fpm.service' -i /etc/systemd/system/uny-php"$small_pkgver"-fpm.service
sed -e '/\[Install\]/a\' -e 'Alias=php'"$(echo "$small_pkgver" | tr -d '.')"'.service' -i /etc/systemd/system/uny-php"$small_pkgver"-fpm.service
systemctl daemon-reload

#############################################################################################
### End of script

cd "$current_dir" || exit
