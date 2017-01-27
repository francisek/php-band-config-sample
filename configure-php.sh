#/usr/bin/env bash -e

php_band_external_add 'ssh' 'https://git.php.net/repository/pecl/networking/ssh2.git' 'master'

php_band_pecl_add_package 'xdebug'
php_band_pecl_add_package 'pecl.php.net/xhprof-0.9.4'
php_band_pecl_add_package 'pecl.php.net/mongodb'
php_band_pecl_add_package 'pecl.php.net/mongo'


php_band_php_config_options=" \
    ${php_band_php_config_options} \
	--with-config-file-scan-dir=${php_band_php_install_dir}/conf.d \
	--enable-cli \
    --enable-fpm \
	--with-pear \
	--with-iconv \
	--with-mysqli \
	--with-pdo-mysql \
	--with-libdir=/lib/x86_64-linux-gnu \
	--enable-ftp \
	--with-gd \
	--enable-gd-native-ttf \
	--with-mcrypt \
	--with-mhash \
	--enable-soap \
	--with-openssl=/usr \
	--with-curl \
	--with-zlib \
	--with-zlib-dir \
	--enable-mbstring \
	--with-jpeg-dir=/usr/lib/x86_64-linux-gnu \
	--with-png-dir=/usr/lib/x68_64-linux-gnu \
	--with-gettext \
	--with-mhash \
	--enable-bcmath \
	--enable-sockets \
	--enable-calendar \
	--enable-zip \
	--enable-pcntl \
	--enable-wddx \
	--enable-mysqlnd \
	--enable-intl \
	--enable-fpm \
	--disable-short-tags \
	--with-readline \
	--with-xsl \
	--disable-zip \
    --with-bz2 \
    --enable-pdo \
    --enable-xml \
    --enable-libxml \
    --enable-dom \
    --enable-simplexml \
    --enable-session \
    --enable-phar \
    --enable-json \
    --enable-ctype \
    --enable-filter
"

custom_copy_files() {
    local files_dir="${PHP_BAND_ASSETS_DIR}/config/files" 
    local relative_node
    if [ ! -d ${files_dir} ]; then
        return
    fi
    for f in $(find ${files_dir}); do
        if [ "$f" = "." -o "$f" = "$files_dir" ]; then
            continue
        fi
        if [ -d "${f}" ]; then
            relative_node=${f#$PHP_BAND_ASSETS_DIR/config/files/}
            if [ ! -d "${php_band_php_install_dir}/${relative_node}" ]; then
                mkdir -p "${php_band_php_install_dir}/${relative_node}"
            fi
        else
            relative_node=$(dirname "${f}")
            relative_node=${relative_node#$PHP_BAND_ASSETS_DIR/config/files/}
            if [ ! -d "${php_band_php_install_dir}/${relative_node}" ]; then
                mkdir -p "${php_band_php_install_dir}/${relative_node}"
            fi
            relative_node=${f#$PHP_BAND_ASSETS_DIR/config/files/}
            cp "${f}" "${php_band_php_install_dir}/${relative_node}"
            php_band_substitute "${php_band_php_install_dir}/${relative_node}"
        fi
    done
}

extension_ssh() {
	local SSH2_URL="${1:-https://github.com/php/pecl-networking-ssh2/archive/}"
    local SSH2_VERSION="${2:-master}"
    local SSH2_SRCDIR=${PHP_BAND_SOURCE_DIR}/$(php_band_build_php_source_dirname)/ext/ssh2/
	if [ -f "${php_band_php_extension_dir}/ssh2.so" ]; then
        echo "SSH2 already built"
        return 0
    fi
	[ -d "${SSH2_SRCDIR}" ] && rm -rf "${SSH2_SRCDIR}"
    cd "${PHP_BAND_SOURCE_DIR}/$(php_band_build_php_source_dirname)/ext"
    git clone --depth 1 --branch "$SSH2_VERSION" $SSH2_URL 
	cd ssh2
	${php_band_php_install_dir}/bin/phpize > /dev/null
	./configure --with-ssh2 --with-php-config=${php_band_php_install_dir}/bin/php-config > /dev/null
	(make $MAKE_OPTS && make install) > /dev/null
	if [ ! -f "${php_band_php_extension_dir}/ssh2.so" ]; then
        echo "Failed"
        return 1
    fi
	if [ ! -f ${php_band_php_install_dir}/conf.d/ssh2.ini ]; then
	  echo "extension=${php_band_php_extension_dir}/ssh2.so" > ${php_band_php_install_dir}/conf.d/ssh2.ini
	fi
	echo "SSH installed"
	touch  .built
	return 0
}

custom_update_version_link() {
    local lnk_name="${PHP_BAND_INST_DIR}/${php_version_major}.${php_version_minor}"
    if [ -L "${lnk_name}" ]; then
        rm "${lnk_name}"
    fi

    if [ ! -e "${lnk_name}" ]; then
        ln -r -s "${php_band_php_install_dir}" "${lnk_name}"
    fi
}

custom_update_alternatives() {
    local alts=$(update-alternatives --list php | grep "/${php_version_major}.${php_version_minor}/")
    local target_path="${PHP_BAND_INST_DIR}/${php_version_major}.${php_version_minor}"
    local alternative_commands=()
    local alternative_command

    find ${target_path}/php/man/ -type f -name "*.[0-9]" -exec gzip --force {} \;
    
    if [ -z "${alts}" ]; then
        echo "We should update alternatives"
    else
        echo "No need to update alternatives"
        return 0
    fi
    
    alternative_command="update-alternatives --install /usr/bin/php php ${target_path}/bin/php ${php_version_major}${php_version_minor} "
    if [ -f "${target_path}/php/man/man1/php.1.gz" ]; then
        alternative_command="${alternative_command} --slave /usr/share/man/man1/php.1.gz php.1.gz ${target_path}/php/man/man1/php.1.gz "
    fi
    alternative_commands+=("$alternative_command; \n")

    if [ -f "${target_path}/bin/php-config" ]; then
        alternative_command="update-alternatives --install /usr/bin/php-config php-config ${target_path}/bin/php-config ${php_version_major}${php_version_minor} "
        if [ -f "${target_path}/php/man/man1/php-config.1.gz" ]; then
            alternative_command="${alternative_command} --slave /usr/share/man/man1/php-config.1.gz php-config.1.gz ${target_path}/php/man/man1/php-config.1.gz "
        fi
        alternative_commands+=("$alternative_command; \n")
    fi

    if [ -f "${target_path}/bin/phpize" ]; then
        alternative_command="update-alternatives --install /usr/bin/phpsize phpize ${target_path}/bin/phpize ${php_version_major}${php_version_minor} "
        if [ -f "${target_path}/php/man/man1/phpize.1.gz" ]; then
            alternative_command="${alternative_command} --slave /usr/share/man/man1/phpize.1.gz phpize.1.gz ${target_path}/php/man/man1/phpize.1.gz "
        fi
        alternative_commands+=("$alternative_command;\n")
    fi

    if [ -f "${target_path}/sbin/php-fpm" ]; then
        alternative_command="update-alternatives --install /usr/sbin/php-fpm php-fpm ${target_path}/sbin/php-fpm ${php_version_major}${php_version_minor} "
        if [ -f "${target_path}/php/man/man8/php-fpm.8.gz" ]; then
            alternative_command="${alternative_command} --slave /usr/share/man/man8/php-fpm.8.gz php-fpm.1.gz ${target_path}/php/man/man8/php-fpm.8.gz "
        fi
        alternative_commands+=("$alternative_command;\n")
    fi




    if [ ! $(id -u) -eq 0 ]; then
        log_info "Cannot update alternatives please run the command "
        echo -e "sudo ( ${alternative_commands[@]} )"
        return 0
    fi
    sh -c "$(echo -e "${alternative_commands[@]}")"
}

custom_set_php_ini() {
    local phpini_file="${php_band_php_install_dir}/lib/php.ini"
    local distfile="$PHP_BAND_SOURCE_DIR/$(php_band_build_php_source_dirname)/php.ini-development"
    if [ -f "$phpini_file" ]; then
        echo "php.ini file exists"
        return 0
    fi
    if [ -f "$distfile" ]; then
        echo "Copying php.ini"
        cp "$distfile" "$phpini_file"
        return 0
    fi
    echo "No php.ini found"
    return 1
}

post_install_php() {
    local command_to_run
	local cwd=$(pwd)
    local command_params 
    chmod +x "${PHP_BAND_SOURCE_DIR}/$(php_band_build_php_source_dirname)/scripts/php-config"
    custom_set_php_ini
    custom_copy_files
	cd "$cwd"

    custom_update_version_link
    custom_update_alternatives
}
