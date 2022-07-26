# First time setup

```,shell
./setup.sh
```

# Script usage

```,
./build.sh [project_name] [action]
[action]:
    i|-i  : current config information
    I|-I  : get chip info
    p|-p  : current patition information
    d|-d  : Get target information
    v|-v  : Validate config and target data
    f|-f  : make flash
    e|-e  : make erase
    m|-m  : make monitor
    b|-b  : make
    c|-c  : make clean
    M|-M  : make menuconfig
    P|-P  : build partition_table
    convertCSV|-convertCSV  : convert CSV to Binary manually
    convertBin|-convertBin  : convert Bin to CSV manually
    fm|-fm: make flash monitor
    fo|-fo|flash_ota_data: flash ota config data
    fb|-fb|flash_boot [(optional) bootloader file]: make flash bootloader
    fp|-fp|flash_ptable: flash partition_table
    fa|-fa|flash_app: flash main application

```

# Examples

## Basic information

-  Get current firmware configuration

```,
thanh@pc ~/build/thanhle/opensource/esp8266/projects (main)
└──▶ ./build.sh hello_world i
=== Common configuration ===
usb             : /dev/ttyUSB0(exist)
platform        : ESP8266
baud            : 115200
chip            : esp8266
flash freq      : 40m
flash size      : 4MB
flash mode      : dio
before flash    : default_reset
after flash     : hard_reset
=== OTA configuration ===
ota enabled     : NO
ota init file   :
ota init addr   :
=== Bootloader configuration ===
bootloader file : /home/thanh/build/thanhle/opensource/esp8266/projects/hello_world/build/bootloader/bootloader.bin
bootloader addr : 0x0000
=== Partition configuration ===
custom csv      : partitions.csv
partition csv   : partitions_singleapp.csv
active csv      : /home/thanh/build/esp8266/ESP8266_RTOS_SDK/components/partition_table/partitions_singleapp.csv
partition file  : /home/thanh/build/thanhle/opensource/esp8266/projects/hello_world/build/partitions_singleapp.bin
partition addr  : 0x8000
=== factory app configuration ===
main app file   : /home/thanh/build/thanhle/opensource/esp8266/projects/hello_world/build/hello-world.bin
main app addr   : 0x10000

```

- Read information from connected esp8266

```,
thanh@pc ~/build/thanhle/opensource/esp8266/projects (main)
└──▶ ./build.sh hello_world I
esptool.py v2.4.0
Connecting....
Chip is ESP8266EX
Features: WiFi
MAC: bc:dd:c2:0f:de:43
Uploading stub...
Running stub...
Stub running...
Manufacturer: 20
Device: 4016
Detected flash size: 4MB
Hard resetting via RTS pin...
```

## Partition table

- Get the partition table configuration of current firmware

```,
thanh@pc ~/build/thanhle/opensource/esp8266/projects (main)
└──▶ ./build.sh hello_world p
Current partition configuration of
# Name,   Type, SubType, Offset,  Size, Flags
# Note: if you change the phy_init or app partition offset, make sure to change the offset in Kconfig.projbuild
nvs,      data, nvs,     0x9000,  0x6000,
phy_init, data, phy,     0xf000,  0x1000,
factory,  app,  factory, 0x10000, 0xF0000

```

- Rebuild the partition table

```,
thanh@pc ~/build/thanhle/opensource/esp8266/projects (main)
└──▶ ./build.sh hello_world P
Toolchain path: /home/thanh/.espressif/tools/xtensa-lx106-elf/esp-2020r3-49-gd5524c1-8.4.0/xtensa-lx106-elf/bin/xtensa-lx106-elf-gcc
Toolchain version: esp-2020r3-49-gd5524c1
Compiler version: 8.4.0
Python requirements from /home/thanh/build/esp8266/ESP8266_RTOS_SDK/requirements.txt are satisfied.
Partition table binary generated. Contents:
*******************************************************************************
# Espressif ESP32 Partition Table
# Name, Type, SubType, Offset, Size, Flags
nvs,data,nvs,0x9000,24K,
phy_init,data,phy,0xf000,4K,
factory,app,factory,0x10000,960K,
*******************************************************************************
Partition flashing command:
python /home/thanh/build/esp8266/ESP8266_RTOS_SDK/components/esptool_py/esptool/esptool.py --chip esp8266 --port /dev/ttyUSB0 --baud 115200 --before default_reset --after hard_reset write_flash 0x8000 /home/thanh/build/thanhle/opensource/esp8266/projects/hello_world/build/partitions_singleapp.bin
Finished build partition table
```

- Flash the partition table to esp8266 device

```,
thanh@pc ~/build/thanhle/opensource/esp8266/projects (main)
└──▶ ./build.sh hello_world fp

=== Common configuration ===
usb             : /dev/ttyUSB0(exist)
platform        : ESP8266
baud            : 115200
chip            : esp8266
flash freq      : 40m
flash size      : 4MB
flash mode      : dio
before flash    : default_reset
after flash     : hard_reset
=== OTA configuration ===
ota enabled     : NO
ota init file   :
ota init addr   :
=== Bootloader configuration ===
bootloader file : /home/thanh/build/thanhle/opensource/esp8266/projects/hello_world/build/bootloader/bootloader.bin
bootloader addr : 0x0000
=== Partition configuration ===
custom csv      : partitions.csv
partition csv   : partitions_singleapp.csv
active csv      : /home/thanh/build/esp8266/ESP8266_RTOS_SDK/components/partition_table/partitions_singleapp.csv
partition file  : /home/thanh/build/thanhle/opensource/esp8266/projects/hello_world/build/partitions_singleapp.bin
partition addr  : 0x8000
=== factory app configuration ===
main app file   : /home/thanh/build/thanhle/opensource/esp8266/projects/hello_world/build/hello-world.bin
main app addr   : 0x10000
Current partition configuration of
# Name,   Type, SubType, Offset,  Size, Flags
# Note: if you change the phy_init or app partition offset, make sure to change the offset in Kconfig.projbuild
nvs,      data, nvs,     0x9000,  0x6000,
phy_init, data, phy,     0xf000,  0x1000,
factory,  app,  factory, 0x10000, 0xF0000,
Flashing /home/thanh/build/thanhle/opensource/esp8266/projects/hello_world/build/partitions_singleapp.bin to 0x8000
esptool.py v2.4.0
Connecting....
Chip is ESP8266EX
Features: WiFi
MAC: bc:dd:c2:0f:de:43
Uploading stub...
Running stub...
Stub running...
Configuring flash size...
Compressed 3072 bytes to 83...
Wrote 3072 bytes (83 compressed) at 0x00008000 in 0.0 seconds (effective 2040.2 kbit/s)...
Hash of data verified.

Leaving...
Hard resetting via RTS pin...
Finished flash partition table only
```

## Bootloader

- Flash bootloader image

```,
thanh@pc ~/build/thanhle/opensource/esp8266/projects (main)
└──▶ ./build.sh hello_world fb
IDF_PATH:/home/thanh/build/esp8266/ESP8266_RTOS_SDK
SDK_DIR:/home/thanh/build/esp8266/ESP8266_RTOS_SDK
Flashing /home/thanh/build/thanhle/opensource/esp8266/projects/hello_world/build/bootloader/bootloader.bin to 0x0000
esptool.py v2.4.0
Connecting....
Chip is ESP8266EX
Features: WiFi
MAC: bc:dd:c2:0f:de:43
Uploading stub...
Running stub...
Stub running...
Configuring flash size...
Compressed 10432 bytes to 7035...
Wrote 10432 bytes (7035 compressed) at 0x00000000 in 0.6 seconds (effective 133.8 kbit/s)...
Hash of data verified.

Leaving...
Hard resetting via RTS pin...
Finished flash bootloader only
```

## User application

- Flash user application

```,
thanh@pc ~/build/thanhle/opensource/esp8266/projects (main)
└──▶ ./build.sh hello_world fa
IDF_PATH:/home/thanh/build/esp8266/ESP8266_RTOS_SDK
SDK_DIR:/home/thanh/build/esp8266/ESP8266_RTOS_SDK
Flashing /home/thanh/build/thanhle/opensource/esp8266/projects/hello_world/build/hello-world.bin to 0x10000
esptool.py v2.4.0
Connecting....
Chip is ESP8266EX
Features: WiFi
MAC: bc:dd:c2:0f:de:43
Uploading stub...
Running stub...
Stub running...
Configuring flash size...
Compressed 129328 bytes to 81428...
Wrote 129328 bytes (81428 compressed) at 0x00010000 in 7.2 seconds (effective 143.9 kbit/s)...
Hash of data verified.

Leaving...
Hard resetting via RTS pin...
Finished flash application only
```
