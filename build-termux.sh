#!/usr/bin/env bash

set -e

pr() { echo -e "\033[0;32m[+] ${1}\033[0m"; }
ask() {
        local y
        for ((n = 0; n < 3; n++)); do
                pr "$1 [y/n]"
                if read -r y; then
                        if [ "$y" = y ]; then
                                return 0
                        elif [ "$y" = n ]; then
                                return 1
                        fi
                fi
                pr "Asking again..."
        done
        return 1
}

pr "Ask for storage permission"
until
        yes | termux-setup-storage >/dev/null 2>&1
        ls /sdcard >/dev/null 2>&1
do sleep 1; done
if [ ! -f ~/.rvmm_"$(date '+%Y%m')" ]; then
        pr "Setting up environment..."
        yes "" | pkg update -y && pkg upgrade -y && pkg install -y git curl jq openjdk-17 zip
        : >~/.rvmm_"$(date '+%Y%m')"
fi
mkdir -p /sdcard/Download/rvcbotbuilds/

if [ -d rvcbotbuilds ] || [ -f config.toml ]; then
        if [ -d rvcbotbuilds ]; then cd rvcbotbuilds; fi
        pr "Checking for rvcbotbuilds updates"
        git fetch
        if git status | grep -q 'is behind\|fatal'; then
                pr "rvcbotbuilds is not synced with upstream."
                pr "Cloning rvcbotbuilds. config.toml will be preserved."
                cd ..
                cp -f rvcbotbuilds/config.toml .
                rm -rf rvcbotbuilds
                git clone https://github.com/Chrispsz/rvcbotbuilds --recurse --depth 1
                mv -f config.toml rvcbotbuilds/config.toml
                cd rvcbotbuilds
        fi
else
        pr "Cloning rvcbotbuilds."
        git clone https://github.com/Chrispsz/rvcbotbuilds --depth 1
        cd rvcbotbuilds
        grep -q 'rvcbotbuilds' ~/.gitconfig 2>/dev/null ||
                git config --global --add safe.directory ~/rvcbotbuilds
fi

[ -f ~/storage/downloads/rvcbotbuilds/config.toml ] ||
        cp config.toml ~/storage/downloads/rvcbotbuilds/config.toml

printf "\n"
until
        if ask "Open 'config.toml' to configure builds?"; then
                am start -a android.intent.action.VIEW -d file:///sdcard/Download/rvcbotbuilds/config.toml -t text/plain
        fi
        ask "Setup is done. Do you want to start building?"
do :; done
cp -f ~/storage/downloads/rvcbotbuilds/config.toml config.toml

./build.sh

cd build
PWD=$(pwd)
for op in *; do
        [ "$op" = "*" ] && {
                pr "glob fail"
                exit 1
        }
        mv -f "${PWD}/${op}" ~/storage/downloads/rvcbotbuilds/"${op}"
done

pr "Outputs are available in /sdcard/Download/rvcbotbuilds folder"
am start -a android.intent.action.VIEW -d file:///sdcard/Download/rvcbotbuilds -t resource/folder
sleep 2
am start -a android.intent.action.VIEW -d file:///sdcard/Download/rvcbotbuilds -t resource/folder
