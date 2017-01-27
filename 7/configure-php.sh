#!/usr/bin/env bash -e

php_band_pecl_remove_package 'pecl.php.net/xhprof-0.9.4'
php_band_pecl_remove_package 'pecl.php.net/mongo'

php_band_external_add 'xhprof' 'https://github.com/RustJason/xhprof.git' 'php7'

extension_xhprof() {
    local repo="$1"
    local branch="${2:-master}"
    local xhprof_src_dir="${PHP_BAND_SOURCE_DIR}/$(php_band_build_php_source_dirname)/ext/xhprof"

    if [ -f "${php_band_php_extension_dir}/xhprof.so" ]; then
        echo "Xhprof already installed"
        return 0
    fi

    [ -d "$xhprof_src_dir" ] && rm -rf "$xhprof_src_dir"
    git clone $repo --branch "$branch" "${xhprof_src_dir}"
    cd "$xhprof_src_dir/extension"
    ${php_band_php_install_dir}/bin/phpize
    ./configure --with-php-config=${php_band_php_install_dir}/bin/php-config
    make ${MAKE_OPTS} && make install
}

