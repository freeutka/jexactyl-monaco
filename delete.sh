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
            *) echo -e "\033[0;33m<Code Editor For Jexactyl> \033[0;31m[✕]\033[0m Invalid choice." ;;
        esac
    done
}

unpatchWebpack() {
    config_file="$target_dir/webpack.config.js"
    if grep -q "monaco-editor" "$config_file"; then
        sed -i '/monaco-editor/,+4d' "$config_file"
        printf "${watermark} Removed Monaco loader rule from webpack.config.js \n"
    else
        printf "${watermark} No Monaco patch found, skipping \n"
    fi
}

rebuildAssets() {
    cd "$target_dir" || { echo "Target directory not found"; exit 1; }
    export NODE_OPTIONS=--openssl-legacy-provider
    npm install -g yarn
    yarn install
    yarn remove esbuild-loader monaco-editor @monaco-editor/react
    yarn build:production || { export NODE_OPTIONS=; yarn build:production; }
    php artisan optimize:clear
}

deleteModule() {
    chooseDirectory
    printf "${watermark} Deleting module... \n"

    unpatchWebpack

    rm -rf "$target_dir/jexactyl-monaco"
    git clone https://github.com/freeutka/jexactyl-monaco.git
    rm -f "$target_dir/resources/scripts/components/server/files/FileEditContainer.tsx"
    mv jexactyl-monaco/original-resources/FileEditContainer.tsx "$target_dir/resources/scripts/components/server/files/"
    rm -rf jexactyl-monaco

    printf "${watermark} Module successfully deleted \n"

    read -p '<Code Editor For Jexactyl> [?] Rebuild panel assets [y/N]? ' yn
    case $yn in [Yy]*) rebuildAssets;; *) exit;; esac
}

read -p '<Code Editor For Jexactyl> [?] Are you sure you want to delete module [y/N]? ' yn
case $yn in [Yy]*) deleteModule;; *) printf "${watermark} Canceled \n"; exit;; esac
