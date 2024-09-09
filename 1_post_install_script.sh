#!/usr/bin/env bash
# shellcheck disable=SC2034,SC1091,SC2154,SC1003,SC2005

current_dir="$(pwd)"
unypkg_script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
unypkg_root_dir="$(cd -- "$unypkg_script_dir"/.. &>/dev/null && pwd)"

cd "$unypkg_root_dir" || exit

#############################################################################################
### Start of script

small_pkgver="$(echo "$(basename "$unypkg_root_dir")" | cut -d. -f1,2)"
mkdir -pv /etc/uny/php/"$small_pkgver"
if [[ ! -f /etc/uny/php/"$small_pkgver"/php.ini ]]; then
    cp -a etc/php.ini-production /etc/uny/php/"$small_pkgver"/php.ini
fi

cp -a php/php/fpm/php-fpm.service /etc/systemd/system/uny-php-fpm.service
#sed "s|.*Alias=.*||g" -i /etc/systemd/system/uny-mariadb.service
sed -e '/\[Install\]/a\' -e 'Alias=php-fpm.service' -i /etc/systemd/system/uny-php-fpm.service
systemctl daemon-reload

#############################################################################################
### End of script

cd "$current_dir" || exit
