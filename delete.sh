#!/bin/bash

if (( $EUID != 0 )); then
    printf "\033[0;33m<Code Editor For Jexactyl> \033[0;31m[✕]\033[0m Please run this program as root \n"
    exit
fi

watermark="\033[0;33m<Code Editor For Jexactyl> \033[0;32m[✓]\033[0m"
target_dir=""

chooseDirectory() {
    echo -e "<Code Editor For Jexactyl> [1] /var/www/jexactyl"
    echo -e "<Code Editor For Jexactyl> [2] /var/www/pterodactyl"

    while true; do
        read -p "<Code Editor For Jexactyl> [?] Choose jexactyl directory [1/2]: " choice
        case "$choice" in
            1) target_dir="/var/www/jexactyl"; break ;;
            2) target_dir="/var/www/pterodactyl"; break ;;
            *) echo -e "\033[0;33m<Code Editor For Jexactyl> \033[0;31m[✕]\033[0m Invalid choice. Please enter 1 or 2." ;;
        esac
    done
}

unpatchWebpack(){
    config_file="$target_dir/webpack.config.js"
    if grep -q "monaco-editor" "$config_file"; then
        sed -i '/monaco-editor/{N;N;N;d}' "$config_file"
        printf "${watermark} Removed Monaco loader rule from webpack.config.js \n"
    else
        printf "${watermark} No Monaco patch found in webpack.config.js \n"
    fi
}

startPterodactyl(){
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | sudo -E bash -
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    nvm install node || { . ~/.nvm/nvm.sh; nvm install node; }
    apt update
    if ! command -v yarn >/dev/null 2>&1; then
        npm i -g yarn
    fi
    yarn
    export NODE_OPTIONS=--openssl-legacy-provider
    yarn build:production || { export NODE_OPTIONS=; yarn build:production; }
    sudo php artisan optimize:clear
}

deleteModule(){
    chooseDirectory
    printf "${watermark} Deleting module... \n"
    cd "$target_dir"

    if ! command -v yarn >/dev/null 2>&1; then
        npm i -g yarn
    fi

    unpatchWebpack

    rm -rvf jexactyl-monaco
    git clone https://github.com/freeutka/jexactyl-monaco.git
    rm -f resources/scripts/components/server/files/FileEditContainer.tsx
    cd jexactyl-monaco
    mv original-resources/FileEditContainer.tsx "$target_dir/resources/scripts/components/server/files/"
    rm -rvf "$target_dir/jexactyl-monaco"
    yarn remove esbuild-loader monaco-editor @monaco-editor/react

    printf "${watermark} Module successfully deleted from your jexactyl repository \n"

    while true; do
        read -p '<Code Editor For Jexactyl> [?] Do you want rebuild panel assets [y/N]? ' yn
        case $yn in
            [Yy]* ) startPterodactyl; break;;
            [Nn]* ) exit;;
            * ) exit;;
        esac
    done
}

while true; do
    read -p '<Code Editor For Jexactyl> [?] Are you sure that you want to delete "Code Editor For Jexactyl" module [y/N]? ' yn
    case $yn in
        [Yy]* ) deleteModule; break;;
        [Nn]* ) printf "${watermark} Canceled \n"; exit;;
        * ) exit;;
    esac
done
