# First time install

```,shell
./setup.sh
```

# Build the project

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
- Example

```
cd projects
./build.sh hello_world M # Make menuconfig
./build.sh hello_world b # Build the application
./build.sh hello_world fm #Flash the application and monitor
```
