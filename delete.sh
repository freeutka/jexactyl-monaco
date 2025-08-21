#!/bin/bash

if (( $EUID != 0 )); then
    printf "\033[0;33m<Code Editor For Jexactyl> \033[0;31m[✕]\033[0m Please run this program as root \n"
    exit
fi

watermark="\033[0;33m<Code Editor For Jexactyl> \033[0;32m[✓]\033[0m"
target_dir=""

initNVM() {
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

    if ! command -v nvm >/dev/null 2>&1; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
        . "$NVM_DIR/nvm.sh"
    fi

    nvm install 20
    nvm use 20
}

chooseDirectory() {
    echo -e "<Code Editor For Jexactyl> [1] /var/www/jexactyl"
    echo -e "<Code Editor For Jexactyl> [2] /var/www/pterodactyl"

    while true; do
        read -p "<Code Editor For Jexactyl> [?] Choose jexactyl directory [1/2]: " choice
        case "$choice" in
            1) target_dir="/var/www/jexactyl"; break ;;
            2) target_dir="/var/www/pterodactyl"; break ;;
            *) echo -e "\033[0;31m[✕] Invalid choice\033[0m" ;;
        esac
    done
}

unpatchWebpack(){
    config_file="$target_dir/webpack.config.js"
    if grep -q "monaco-editor" "$config_file"; then
        sed -i '/monaco-editor/{N;N;N;d}' "$config_file"
        printf "${watermark} Removed Monaco loader rule \n"
    else
        printf "${watermark} No Monaco patch found \n"
    fi
}

startPterodactyl(){
    initNVM
    apt update
    npm i -g yarn

    cd "$target_dir"
    export NODE_OPTIONS=--openssl-legacy-provider
    yarn install
    yarn build:production
    sudo php artisan optimize:clear
}

deleteModule(){
    chooseDirectory
    printf "${watermark} Deleting module... \n"
    cd "$target_dir"

    unpatchWebpack

    rm -rf jexactyl-monaco
    git clone https://github.com/freeutka/jexactyl-monaco.git

    cp jexactyl-monaco/original-resources/FileEditContainer.tsx \
       "$target_dir/resources/scripts/components/server/files/FileEditContainer.tsx"

    rm -rf jexactyl-monaco

    initNVM
    yarn remove esbuild-loader monaco-editor @monaco-editor/react

    printf "${watermark} Module successfully deleted \n"

    while true; do
        read -p '<Code Editor For Jexactyl> [?] Rebuild panel assets [y/N]? ' yn
        case $yn in
            [Yy]* ) startPterodactyl; break ;;
            [Nn]* ) exit ;;
            * ) exit ;;
        esac
    done
}

while true; do
    read -p '<Code Editor For Jexactyl> [?] Confirm deletion [y/N]: ' yn
    case $yn in
        [Yy]* ) deleteModule; break ;;
        [Nn]* ) printf "${watermark} Canceled \n"; exit ;;
        * ) exit ;;
    esac
done
