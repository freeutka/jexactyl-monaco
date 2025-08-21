#!/bin/bash

if (( $EUID != 0 )); then
    printf "\033[0;33m<Code Editor For Jexactyl> \033[0;31m[✕]\033[0m Please run this program as root \n"
    exit
fi

watermark="\033[0;33m<Code Editor For Jexactyl> \033[0;32m[✓]\033[0m"
target_dir=""

chooseDirectory() {
    echo -e "<Code Editor For Jexactyl> [1] /var/www/jexactyl   (official Jexactyl)"
    echo -e "<Code Editor For Jexactyl> [2] /var/www/pterodactyl (migrated from Pterodactyl)"
    while true; do
        read -p "<Code Editor For Jexactyl> [?] Choose directory [1/2]: " choice
        case "$choice" in
            1) target_dir="/var/www/jexactyl"; break ;;
            2) target_dir="/var/www/pterodactyl"; break ;;
            *) echo -e "${watermark} Invalid choice. Please enter 1 or 2." ;;
        esac
    done
}

patchWebpack(){
    config_file="$target_dir/webpack.config.js"
    if ! grep -q "monaco-editor" "$config_file"; then
        if ! grep -q "require('path')" "$config_file"; then
            sed -i "1i const path = require('path');" "$config_file"
        fi

        sed -i '/test: \\/\\.mjs\\$/{n;N;a \
            {\
                test: /\.m?js$/, \
                include: path.resolve(__dirname, '\''node_modules/monaco-editor'\''), \
                type: '\''javascript/auto'\'', \
                loader: '\''esbuild-loader'\'', \
            },' "$config_file"

        printf "${watermark} Patched webpack.config.js with Monaco loader rule \n"
    else
        printf "${watermark} Webpack already patched, skipping \n"
    fi
}

startPterodactyl(){
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    nvm install node
    npm i -g yarn
    yarn
    yarn add esbuild-loader monaco-editor @monaco-editor/react
    export NODE_OPTIONS=--openssl-legacy-provider
    yarn build:production || { export NODE_OPTIONS=; yarn build:production; }
    php artisan optimize:clear
}

installModule(){
    chooseDirectory
    printf "${watermark} Installing module... \n"
    cd "$target_dir"

    patchWebpack

    rm -rvf jexactyl-monaco
    git clone https://github.com/freeutka/jexactyl-monaco.git
    rm -f resources/scripts/components/server/files/FileEditContainer.tsx
    cd jexactyl-monaco
    mv resources/FileEditContainer.tsx "$target_dir/resources/scripts/components/server/files/"
    rm -rvf "$target_dir/jexactyl-monaco"

    printf "${watermark} Module fully installed \n"

    while true; do
        read -p '<Code Editor For Jexactyl> [?] Rebuild panel assets [y/N]? ' yn
        case $yn in
            [Yy]* ) startPterodactyl; break;;
            [Nn]* ) exit;;
            * ) exit;;
        esac
    done
}

while true; do
    read -p '<Code Editor For Jexactyl> [?] Are you sure you want to install module [y/N]? ' yn
    case $yn in
        [Yy]* ) installModule; break;;
        [Nn]* ) printf "${watermark} Canceled \n"; exit;;
        * ) exit;;
    esac
done
