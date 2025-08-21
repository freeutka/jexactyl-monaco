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

patchWebpack(){
    config_file="$target_dir/webpack.config.js"
    if ! grep -q "monaco-editor" "$config_file"; then
        sed -i "/test: \\\/\.mjs\\\$/,/{N;a \ \ \ \ \ \ \ \ {\n                test: \\\/\.m?js\\\$/,\n                include: /node_modules\/@monaco-editor/,\n                type: 'javascript/auto',\n            }," "$config_file"
        printf "${watermark} Patched webpack.config.js with Monaco loader rule \n"
    else
        printf "${watermark} Monaco patch already exists in webpack.config.js \n"
    fi
}

unpatchWebpack(){
    config_file="$target_dir/webpack.config.js"
    if grep -q "monaco-editor" "$config_file"; then
        sed -i "/monaco-editor/{N;N;N;d}" "$config_file"
        printf "${watermark} Removed Monaco loader rule from webpack.config.js \n"
    else
        printf "${watermark} No Monaco patch found in webpack.config.js \n"
    fi
}

startPterodactyl(){
    initNVM
    apt update
    npm i -g yarn

    cd "$target_dir"
    export NODE_OPTIONS=--openssl-legacy-provider
    yarn install
    yarn build:production || {
        printf "${watermark} Retry build without NODE_OPTIONS \n"
        export NODE_OPTIONS=
        yarn build:production
    }
    sudo php artisan optimize:clear
}

installModule(){
    chooseDirectory
    printf "${watermark} Installing module... \n"
    cd "$target_dir"

    patchWebpack

    rm -rvf jexactyl-monaco
    git clone https://github.com/freeutka/jexactyl-monaco.git

    cp jexactyl-monaco/resources/FileEditContainer.tsx \
       "$target_dir/resources/scripts/components/server/files/FileEditContainer.tsx"

    rm -rvf "$target_dir/jexactyl-monaco"

    initNVM
    yarn add esbuild-loader monaco-editor @monaco-editor/react

    printf "${watermark} Module successfully installed to your jexactyl repository \n"

    while true; do
        read -p '<Code Editor For Jexactyl> [?] Do you want rebuild panel assets [y/N]? ' yn
        case $yn in
            [Yy]* ) startPterodactyl; break;;
            [Nn]* ) exit;;
            * ) exit;;
        esac
    done
}

deleteModule(){
    chooseDirectory
    printf "${watermark} Deleting module... \n"
    cd "$target_dir"

    unpatchWebpack

    rm -rvf jexactyl-monaco
    git clone https://github.com/freeutka/jexactyl-monaco.git

    cp jexactyl-monaco/original-resources/FileEditContainer.tsx \
       "$target_dir/resources/scripts/components/server/files/FileEditContainer.tsx"

    rm -rvf "$target_dir/jexactyl-monaco"

    initNVM
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
    echo "<Code Editor For Jexactyl> [1] Install module"
    echo "<Code Editor For Jexactyl> [2] Delete module"
    read -p '<Code Editor For Jexactyl> [?] Choose an action [1/2]: ' action
    case $action in
        1) installModule; break;;
        2) deleteModule; break;;
        *) echo "Invalid choice";;
    esac
done
