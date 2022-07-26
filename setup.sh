#! /bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YEL='\033[0;33m'
BLUE='\033[0;34m'
HONG='\033[0;35m'
COL='\033[0;36m'
NC='\033[0m' # No Color
HERE="`pwd`"

SDK_URL="https://github.com/espressif/ESP8266_RTOS_SDK.git"
SDK_BRANCH="release/v3.4"
TOOLCHAIN_URL=""
TOOLCHAIN_FOLDER="xtensa-lx106-elf"
SDK_FOLDER="ESP8266_RTOS_SDK"
TOOLCHAIN_DIR="${HOME}/build/esp8266/${TOOLCHAIN_FOLDER}"
SDK_DIR="${HOME}/build/esp8266/${SDK_FOLDER}"
OS="$(uname -a | grep Darwin | awk '{print $1}')"
UB_VERSION="$(lsb_release -d | awk '{print $3}')"

function LOG_E() {
	echo -e "${RED}${NC} $*"
}
function LOG_I() {
	echo -e "${GREEN}${NC} $*"
}
function LOG_W() {
	echo -e "${YEL}${NC} $*"
}

if [ "${OS}" = "Darwin" ] ; then
    sudo easy_install pip
    pip install --user pyserial
    brew install cmake ninja
    TOOLCHAIN_SOURCE="xtensa-lx106-elf-macos-1.22.0-100-ge567ec7-5.2.0.tar.gz"
else
    TOOLCHAIN_SOURCE="xtensa-lx106-elf-linux64-1.22.0-92-g8facf4c-5.2.0.tar.gz"
fi
TOOLCHAIN_LINK="https://dl.espressif.com/dl/${TOOLCHAIN_SOURCE}"


function setup_sdk()
{

    [ ! -f "`which curl`" ] && sudo apt-get install curl

    if [[ $UB_VERSION == *"20."* ]] ; then
        sudo apt install python3
        curl https://bootstrap.pypa.io/get-pip.py --output get-pip.py
        sudo python3 get-pip.py
    fi

    sudo apt-get install gcc git wget make libncurses-dev flex bison gperf python3-pip python3-setuptools -y
    sudo apt-get install python3-serial python3-cryptography python3-future python3-pyparsing python3-pyelftools -y
    pip3 install click
    pip3 install esptool

    [ ! -d "${HOME}/build" ] && {
        mkdir -p "${HOME}/build"
    }
    [ ! -d "${HOME}/build/esp8266" ] && {
        mkdir -p ${HOME}/build/esp8266
    }
    cd ${HOME}/build/esp8266
    git clone --depth 100 --single-branch --branch ${SDK_BRANCH} --recursive  ${SDK_URL} ${SDK_FOLDER}
    [ ! -d "${HOME}/build/esp8266/${SDK_FOLDER}" ] && {
        LOG_E "Failed to clone ${SDK_URL} to ${SDK_FOLDER}"
        exit 1
    }
    cd ${HOME}/build/esp8266/${SDK_FOLDER}
    ./install.sh
    source export.sh
}

function setup_toolchain()
{
    cd ${HOME}/build/esp8266/
    wget ${TOOLCHAIN_LINK}
    tar -xf ${TOOLCHAIN_SOURCE}
    rm -rf ${TOOLCHAIN_SOURCE}
}

if [ ! -d ${SDK_DIR} ] ; then
    setup_sdk
else
    cd ${SDK_DIR}
    git pull origin ${SDK_BRANCH}
    cd ${SDK_FOLDER}
    ./install.sh
    source export.sh
fi

if [ ! -d ${TOOLCHAIN_DIR} ] ; then
    setup_toolchain
fi


