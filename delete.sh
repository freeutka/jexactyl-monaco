#!/bin/bash

if (( $EUID != 0 )); then
    printf "\033[0;33m<Code Editor For Jexactyl> \033[0;31m[✕]\033[0m Please run this program as root \n"
    exit
fi

watermark="\033[0;33m<Code Editor For Jexactyl> \033[0;32m[✓]\033[0m"
target_dir=""

chooseDirectory() {
    echo -e "<Code Editor For Jexactyl> [1] /var/www/jexactyl   (choose this if you installed the panel using the official Jexactyl documentation)"
    echo -e "<Code Editor For Jexactyl> [2] /var/www/pterodactyl (choose this if you migrated from Pterodactyl to Jexactyl)"

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
    nvm install node || {
        printf "${watermark} nvm command not found, trying to source nvm script directly... \n"
        . ~/.nvm/nvm.sh
        nvm install node
    }
    apt update

    npm i -g yarn
    yarn
    yarn remove esbuild-loader monaco-editor @monaco-editor/react
    export NODE_OPTIONS=--openssl-legacy-provider
    yarn build:production || {
        printf "${watermark} node: --openssl-legacy-provider is not allowed in NODE_OPTIONS \n"
        export NODE_OPTIONS=
        yarn build:production
    }
    sudo php artisan optimize:clear
}

deleteModule(){
    chooseDirectory
    printf "${watermark} Deleting module... \n"
    cd "$target_dir"

    unpatchWebpack

    cd "$target_dir" || exit 1
    rm -rvf jexactyl-monaco
    git clone https://github.com/freeutka/jexactyl-monaco.git
    rm -f resources/scripts/components/server/files/FileEditContainer.tsx
    mv jexactyl-monaco/original-resources/FileEditContainer.tsx "$target_dir/resources/scripts/components/server/files/"
    cd "$target_dir"
    rm -rvf jexactyl-monaco


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
    read -p '<Code Editor For Jexactyl> [?] Are you sure that you want to delete "Code Editor For Jexactyls" module [y/N]? ' yn
    case $yn in
        [Yy]* ) deleteModule; break;;
        [Nn]* ) printf "${watermark} Canceled \n"; exit;;
        * ) exit;;
    esac
done
