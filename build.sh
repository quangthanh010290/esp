#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YEL='\033[0;33m'
BLUE='\033[0;34m'
HONG='\033[0;35m'
COL='\033[0;36m'
NC='\033[0m' # No Color
HERE=$(pwd)
PLATFORM=""
PLATFORM_ESP32="ESP32"
PLATFORM_ESP8266="ESP8266"
OTA_ENABLED="NO"
TARGET=""

function LOG_E() {
	echo -e "${RED}$*${NC}"
}
function LOG_I() {
	echo -e "${GREEN}$*${NC}"
}
function LOG_W() {
	echo -e "${YEL}$*${NC}"
}

# check to select  esp8266 or esp32 SDK
if [[ $HERE == *"esp8266"* ]]; then
	SDK_DIR="${HOME}/build/esp8266/ESP8266_RTOS_SDK"
	PLATFORM=${PLATFORM_ESP8266}
fi
if [[ $HERE == *"esp32"* ]]; then
	SDK_DIR="${HOME}/build/esp-idf"
	PLATFORM=${PLATFORM_ESP32}
fi
[ ! -d "${SDK_DIR}" ] && {
	LOG_E "SDK is not existed, please run esp[xxx]/setup.sh first"
	exit
}

# setup SDK and environment
export IDF_PATH="${SDK_DIR}"
if [ -d "${HOME}/build/esp-idf" ]; then
	ESPTOOL="${HOME}/build/esp-idf/components/esptool_py/esptool/esptool.py"
else
	ESPTOOL="${IDF_PATH}/components/esptool_py/esptool/esptool.py"
fi
LOG_I "IDF_PATH:$IDF_PATH"
LOG_I "SDK_DIR:$SDK_DIR"
source ${SDK_DIR}/export.sh >/dev/null 2>&1

PARTITION_TOOL="${IDF_PATH}/components/partition_table/gen_esp32part.py"

# setup SDK and environment
function check_port() {
	local port=$1
	rm -rf ./out
	ls -al ${port} >./out 2>&1
	[ -n "$(grep 'No such file or directory' ./out)" ] && {
		rm -rf ./out
		return 0
	}
	rm -rf ./out
	return 1
}
# get configuration from target connected to host machine
function get_target_info() {
	rm -rf ./out
	python3 ${ESPTOOL} flash_id >./out
	TARGET="$(grep 'Detecting chip type...' ./out | awk '{print $4}')"
	TARGET_FLASH_SIZE="$(grep 'Detected flash size:' ./out | awk '{print $4}')"
	TARGET_FLASH_FREQ="$(grep 'Crystal is' ./out | awk '{print $3}')"
	TARGET_PORT="$(grep 'Serial port' ./out | awk '{print $3}')"
	# TARGET="$(grep 'Detecting chip type...' ./out | awk '{print $4}')"
	LOG_I "detected:"
	echo "target      :${TARGET}"
	echo "flash_size  :${TARGET_FLASH_SIZE}"
	echo "flash_freq  :${TARGET_FLASH_FREQ}"
	echo "serial port :${TARGET_PORT}"
	rm -rf ./out
}

# get current configuration from sdkconfig file
function get_config_info() {
	PROJECT=${1}
	HERE=$(pwd)
	[ ! -d "${PROJECT}" ] && {
		LOG_E "project ${PROJECT} does not exist"
		exit 1
	}
	cd ${PROJECT}
	APP_NAME="$(grep project\( ./CMakeLists.txt | cut -d\( -f2 | sed 's/)//g')"
	[ -f "build/${APP_NAME}.bin" ] && {
		APP_FILE=$(readlink -f "build/${APP_NAME}.bin")
	}
	[ ! -f "./sdkconfig" ] && {
		LOG_E "sdkconfig is not exist, tun ${0} . M first"
		return 0
	}
	PORT="$(grep CONFIG_ESPTOOLPY_PORT= ./sdkconfig | cut -d= -f2 | sed 's/"//g')"
	BAUD="$(grep CONFIG_ESPTOOLPY_BAUD= ./sdkconfig | cut -d= -f2 | sed 's/"//g')"
	CHIP="$(grep CONFIG_IDF_TARGET= ./sdkconfig | cut -d= -f2 | sed 's/"//g')"
	FLASH_FREQ="$(grep CONFIG_ESPTOOLPY_FLASHFREQ= ./sdkconfig | cut -d= -f2 | sed 's/"//g')"
	FLASH_SIZE="$(grep CONFIG_ESPTOOLPY_FLASHSIZE= ./sdkconfig | cut -d= -f2 | sed 's/"//g')"
	PARTITION_ADDRESS="$(grep CONFIG_PARTITION_TABLE_OFFSET= ./sdkconfig | cut -d= -f2 | sed 's/"//g')"
	PARTITION_CSV="$(grep CONFIG_PARTITION_TABLE_FILENAME= ./sdkconfig | cut -d= -f2 | sed 's/"//g')"
	CUSTOM_CSV="$(grep CONFIG_PARTITION_TABLE_CUSTOM_FILENAME= ./sdkconfig | cut -d= -f2 | sed 's/"//g')"
	USE_CUSTOM_CSV="$(grep CONFIG_PARTITION_TABLE_CUSTOM=y ./sdkconfig | cut -d= -f2 | sed 's/"//g')"

	ACTIVE_CSV=${PARTITION_CSV}

	PARTITION_BIN="$(echo ${ACTIVE_CSV} | cut -d. -f1)".bin
	[ -f "build/${PARTITION_BIN}" ] && {
		PARTITION_BIN=$(readlink -f "build/${PARTITION_BIN}")
	}
	[ ! -z "${ACTIVE_CSV}" ] && {
		ACTIVE_CSV="${IDF_PATH}/components/partition_table/${ACTIVE_CSV}"
	}
	[ "${USE_CUSTOM_CSV}" = "y" ] && {
		ACTIVE_CSV="${CUSTOM_CSV}"
		ACTIVE_CSV=$(readlink -f "${ACTIVE_CSV}")
	}

	FLASH_MODE="$(grep CONFIG_ESPTOOLPY_FLASHMODE= ./sdkconfig | cut -d= -f2 | sed 's/"//g')"
	BEFORE_FLASH="$(grep CONFIG_ESPTOOLPY_BEFORE= ./sdkconfig | cut -d= -f2 | sed 's/"//g')"
	AFTER_FLASH="$(grep CONFIG_ESPTOOLPY_AFTER= ./sdkconfig | cut -d= -f2 | sed 's/"//g')"
	BOOTLOADER_FILE="${HERE}/${PROJECT}/build/bootloader/bootloader.bin"

	#Recalculate Offset base on firmware type
	BOOTLOADER_ADDRESS=0x0000
	if [[ $ACTIVE_CSV == *"components/partition_table/partitions_singleapp.csv"* ]]; then
		OTA_ENABLED="NO"
		OTA_INIT_FILE=""
		OTA_INIT_ADDR=""
	fi
	if [[ $ACTIVE_CSV == *"components/partition_table/partitions_two_ota.csv"* ]]; then
		OTA_ENABLED="YES"
		OTA_INIT_FILE="${HERE}/build/ota_data_initial.bin"
		OTA_INIT_ADDR=0xd000
		[ "${PLATFORM}" = "${PLATFORM_ESP32}" ] && BOOTLOADER_ADDRESS=0x1000
	fi

	MAIN_APP_ADDRESS=0x10000
	cd $HERE
}
function print_partition_info() {
	LOG_I "Current partition configuration of ${PARTITION_FILE}"
	cat ${ACTIVE_CSV}
}

function validate_config() {
	get_target_info
	if [ ! "${TARGET}" = "${PLATFORM}" ]; then
		LOG_E "connected target ${TARGET} not match with sdk ${PLATFORM}"
	else
		LOG_I "connected target ${TARGET} match with sdk ${PLATFORM}"
	fi

	if [ ! "${TARGET_FLASH_SIZE}" = "${FLASH_SIZE}" ]; then
		LOG_E "config flash size ${FLASH_SIZE} not match with target flash size ${TARGET_FLASH_SIZE}"
	else
		LOG_I "config flash size ${FLASH_SIZE} match with target flash size ${TARGET_FLASH_SIZE}"
	fi

	if [ ! "${TARGET_PORT}" = "${PORT}" ]; then
		LOG_E "config port ${PORT} not match with target port ${TARGET_PORT}"
	else
		LOG_I "config port ${PORT} not match with target port ${TARGET_PORT}"
	fi

}
function print_info() {
	LOG_W "=== Common configuration ==="
	check_port ${PORT}
	if [ $? = 1 ]; then
		echo -e "usb             : ${PORT}(${GREEN}exist${NC})"
	else
		echo -e "usb             : ${PORT}(${RED} not exist${NC})"
	fi
	echo "platform        : ${PLATFORM}"
	echo "baud            : ${BAUD}"
	echo "chip            : ${CHIP}"
	echo "flash freq      : ${FLASH_FREQ}"
	echo "flash size      : ${FLASH_SIZE}"
	echo "flash mode      : ${FLASH_MODE}"
	echo "before flash    : ${BEFORE_FLASH}"
	echo "after flash     : ${AFTER_FLASH}"

	LOG_W "=== OTA configuration ==="
	echo "ota enabled     : ${OTA_ENABLED}"
	echo "ota init file   : ${OTA_INIT_FILE}"
	echo "ota init addr   : ${OTA_INIT_ADDR}"

	LOG_W "=== Bootloader configuration ==="
	echo "bootloader file : ${BOOTLOADER_FILE}"
	echo "bootloader addr : ${BOOTLOADER_ADDRESS}"

	LOG_W "=== Partition configuration ==="
	echo "custom csv      : ${CUSTOM_CSV}"
	echo "partition csv   : ${PARTITION_CSV}"
	echo "active csv      : ${ACTIVE_CSV}"
	echo "partition file  : ${PARTITION_BIN}"
	echo "partition addr  : ${PARTITION_ADDRESS}"

	LOG_W "=== factory app configuration ==="
	echo "main app file   : ${APP_FILE}"
	echo "main app addr   : ${MAIN_APP_ADDRESS}"
}

function prin_usage() {
	echo -e "${HONG}example: ./build.sh [project_name] [action]${NC}"
	echo -e "[action]: "
	echo -e "    i|-i  : current config information"
	echo -e "    I|-I  : get chip info"
	echo -e "    p|-p  : current patition information"
	echo -e "    d|-d  : Get target information"
	echo -e "    v|-v  : Validate config and target data"
	echo -e "    f|-f  : make flash"
	echo -e "    e|-e  : make erase"
	echo -e "    m|-m  : make monitor"
	echo -e "    b|-b  : make"
	echo -e "    c|-c  : make clean"
	echo -e "    M|-M  : make menuconfig"
	echo -e "    P|-P  : build partition_table"
	echo -e "    convertCSV|-convertCSV  : convert CSV to Binary manually"
	echo -e "    convertBin|-convertBin  : convert Bin to CSV manually"
	echo -e "    fm|-fm: make flash monitor"
	echo -e "    fo|-fo|flash_ota_data: flash ota config data"
	echo -e "    fb|-fb|flash_boot [(optional) bootloader file]: make flash bootloader"
	echo -e "    fp|-fp|flash_ptable: flash partition_table"
	echo -e "    fa|-fa|flash_app: flash main application"
}

PROJECT=${1}
ACTION=${2}

if [ "${PROJECT}" = "" ]; then
	echo -e "${RED} Please select project to build ${NC}"
	prin_usage
	exit 1
fi
if [ "${ACTION}" = "" ]; then
	echo -e "${YEL} no option specify, select default action: build ${NC}"
	ACTION="b"
fi
get_config_info ${PROJECT}
case ${ACTION} in
i | -i | info)
	print_info
	[ -d "build" -a -f "${PARTITION_FILE}" ] && print_partition_info
	;;
I | -I)
	python3 ${ESPTOOL} --chip $CHIP --port ${PORT} --baud ${BAUD} flash_id
	;;
p | -p | partition)
	print_partition_info
	;;
d | -d | detect_target)
	get_target_info
	;;
v | -v | detect_target)
	validate_config
	;;
f | -f)
	cd ${PROJECT}
	make flash -j
	LOG_I "Finished flash"
	;;
e | -e)
	cd ${PROJECT}
	make erase_flash
	LOG_I "Finished erasing"
	;;
m | -m)
	cd ${PROJECT}
	make monitor
	# --- Quit: Ctrl+] | Menu: Ctrl+T | Help: Ctrl+T followed by Ctrl+H ---
	LOG_I "Finished monitor"
	;;
b | -b)
	cd ${PROJECT}
	if [ ! -f "sdkconfig" ]; then
		make menuconfig
	fi
	make -j
	LOG_I "Finished build"
	;;
c | -c)
	cd ${PROJECT}
	rm -rf build
	LOG_I "Finished clean"
	;;
M | -M)
	cd ${PROJECT}
	make menuconfig
	cd $HERE
	get_config_info ${PROJECT}
	LOG_I "Finished menuconfig"
	;;
P | -P)
	cd ${PROJECT}
	make partition_table
	LOG_I "Finished build partition table"
	;;
convertCSV | -convertCSV)
	cd ${PROJECT}
	IN_FILE="partitions.csv"
	OUT_FILE="partitions.bin"
	[ ! -f "${IN_FILE}" ] && {
		LOG_E "${IN_FILE} is not exist"
		exit
	}
	python3 ${PARTITION_TOOL} --verify ${IN_FILE} ${OUT_FILE} >./out 2>&1
	[ -n "$(grep Error out)" ] && {
		cat ./out
		rm -rf ./out
		LOG_E "Failed to generate ${OUT_FILE}"
		exit
	}
	rm -rf ./out
	LOG_I "Finished conver CSV to bin"
	python3 ${PARTITION_TOOL} ${OUT_FILE}
	;;
convertBin | -convertBin)
	cd ${PROJECT}
	IN_FILE="${PARTITION_BIN}"
	OUT_FILE="tmp.csv"
	[ ! -f "${IN_FILE}" ] && {
		LOG_E "${IN_FILE} is not exist"
		exit
	}
	python3 ${PARTITION_TOOL} --verify ${IN_FILE} ${OUT_FILE}
	LOG_I "Finished conver Bin to CSV"
	cat ${OUT_FILE}
	;;
fm | -fm)
	cd ${PROJECT}
	make flash monitor
	LOG_I "Finished flash and monitor"
	;;
fo | -fo | flash_ota_data)
	cd ${PROJECT}
	[ ! "${OTA_ENABLED}" = "YES" ] && {
		LOG_E "Current partition type not supported OTA, run ${0} . M"
		exit
	}
	[ ! -z "${3}" ] && {
		LOG_I "Use custom ota data file"
		if [ ! -f "${3}" ]; then
			LOG_E "${3} is not exist, use default file"
			[ ! -f "${OTA_INIT_FILE}" ] && {
				LOG_E "${OTA_INIT_FILE} is not exist"
				exit
			}
		else
			OTA_INIT_FILE=${3}
		fi

	}
	[ ! -z "${4}" ] && {
		LOG_I "Use custom ota data address: ${4}"
		OTA_INIT_ADDR=${4}
	}
	[ ! -f "${OTA_INIT_FILE}" ] && {
		LOG_E "${OTA_INIT_FILE} not exist, run ${0} . b"
		exit
	}
	LOG_W "Flashing ${OTA_INIT_FILE} to ${OTA_INIT_ADDR}"
	python3 ${ESPTOOL} --chip $CHIP --port ${PORT} --baud ${BAUD} --before ${BEFORE_FLASH} --after ${AFTER_FLASH} write_flash -z --flash_mode ${FLASH_MODE} --flash_freq ${FLASH_FREQ} --flash_size ${FLASH_SIZE} ${OTA_INIT_ADDR} ${OTA_INIT_FILE}
	LOG_I "Finished flash bootloader only"
	;;
fb | -fb | flash_boot)
	cd ${PROJECT}
	[ ! -z "${3}" ] && {
		LOG_I "Use custom bootloader binary"
		if [ ! -f "${3}" ]; then
			LOG_E "${3} is not exist, use default file"
			[ ! -f "${BOOTLOADER_FILE}" ] && {
				LOG_E "${BOOTLOADER_FILE} is not exist"
				exit
			}
		else
			BOOTLOADER_FILE=${3}
		fi

	}
	[ ! -z "${4}" ] && {
		LOG_I "Use custom bootloader address: ${4}"
		BOOTLOADER_ADDRESS=${4}
	}
	LOG_W "Flashing ${BOOTLOADER_FILE} to ${BOOTLOADER_ADDRESS}"
	python3 ${ESPTOOL} --chip $CHIP --port ${PORT} --baud ${BAUD} --before ${BEFORE_FLASH} --after ${AFTER_FLASH} write_flash -z --flash_mode ${FLASH_MODE} --flash_freq ${FLASH_FREQ} --flash_size ${FLASH_SIZE} ${BOOTLOADER_ADDRESS} ${BOOTLOADER_FILE}
	LOG_I "Finished flash bootloader only"
	;;
fp | -fp | flash_ptable)
	cd ${PROJECT}
	HERE="$(pwd)"
	[ ! -f "${PARTITION_BIN}" ] && {
		LOG_E "${PARTITION_BIN} is not exist"
		exit
	}
	[ -z "${PARTITION_ADDRESS}" ] && {
		LOG_E "${PARTITION_ADDRESS} is not valid"
		exit
	}
	print_info
	print_partition_info
	LOG_W "Flashing ${PARTITION_BIN} to ${PARTITION_ADDRESS}"
	python3 ${ESPTOOL} --chip ${CHIP} --port ${PORT} --baud ${BAUD} --before ${BEFORE_FLASH} --after ${AFTER_FLASH} write_flash -z --flash_mode ${FLASH_MODE} --flash_freq ${FLASH_FREQ} --flash_size ${FLASH_SIZE} ${PARTITION_ADDRESS} ${PARTITION_BIN}
	LOG_I "Finished flash partition table only"
	;;
fa | -fa | flash_app)
	[ ! -z "${3}" ] && {
		LOG_I "Use custom app binary"
		if [ ! -f "${3}" ]; then
			LOG_E "${3} is not exist, use default file"
			[ ! -f "${APP_FILE}" ] && {
				LOG_E "${APP_FILE} is not exist"
				exit
			}
		else
			APP_FILE=${3}
		fi

	}
	[ ! -z "${4}" ] && {
		LOG_I "Use custom app address: ${4}"
		MAIN_APP_ADDRESS=${4}
	}
	LOG_W "Flashing ${APP_FILE} to ${MAIN_APP_ADDRESS}"
	python3 ${ESPTOOL} --chip ${CHIP} --port ${PORT} --baud ${BAUD} --before ${BEFORE_FLASH} --after ${AFTER_FLASH} write_flash -z --flash_mode ${FLASH_MODE} --flash_freq ${FLASH_FREQ} --flash_size ${FLASH_SIZE} ${MAIN_APP_ADDRESS} ${APP_FILE}
	LOG_I "Finished flash application only"
	;;
*)
	prin_usage
	;;
esac
