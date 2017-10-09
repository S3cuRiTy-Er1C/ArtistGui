#!/usr/bin/env bash

### Building ARTist on a remote machine that is included locally via ssh.
### First argument is expected to be the file path of the corresponding ssh config for a particular sdk level.
### Execute from ArtistGUI root dir!

# read parameter as configuration file path
config=$1
# include the config file

if [ ! -f ${config} ]; then
    echo "No configuration for make script found: file '${config}' is missing."
    exit
fi

echo "ARTist SSH build started"

# set the configuration values
source $config

ndk_binary_strip="${ndk_path}/toolchains/arm-linux-androideabi-4.9/prebuilt/linux-x86_64/bin/arm-linux-androideabi-strip"

#server_aosp_path = ${server_mount_path}
#server_art_path="${server_mount_path}/art/"
#server_art_git_path="${server_art_path}/.git"

api_level_string="android-${api_level}"

dex2oat_path="./assets/artist/${api_level_string}/dex2oat"
art_version_file="assets/VERSION_ARTIST-${api_level_string}.md"

mounted_art_path="${mounted_aosp}/art/"
mounted_art_git_path="${mounted_art_path}/.git"

dexToOatLibs=(
    "libc.so"
    "libc++.so"
    "libnativebridge.so"
    "libnativehelper.so"
    "libnativeloader.so "
    "libart.so"
    "libart-compiler.so"
    "libvixl.so"
    "libbacktrace.so"
    "libbase.so"
    "liblog.so"
    "libcutils.so"
    "libsigchain.so"
    "libunwind.so"
    "libutils.so"
    "libdl.so"
    "libm.so"
    "liblzma.so"
    "liblz4.so"
)

# do the actual building
if [ "${arch_64}" = true ]; then
    echo "Connecting to ${server_alias}, building Android [arm64]"
else
    echo "Connecting to ${server_alias}, building Android [arm32]"
fi

if [ "${arch_64}" = true ]; then
#    ssh ${server_alias} "cd ${server_aosp} ; . build/envsetup.sh; lunch aosp_arm64-eng; mmma art/ -j${threads}"
    ssh ${server_alias} "cd ${server_aosp} ; . build/envsetup.sh; lunch aosp_arm64-eng; mmm art/ -j${threads}"
else
    #ssh ${server_alias} "cd ${server_aosp} ; . build/envsetup.sh; lunch aosp_arm-eng; mmma art/ -j${threads}"
    ssh ${server_alias} "cd ${server_aosp} ; . build/envsetup.sh; lunch aosp_arm-eng; mmm art/ -j${threads}"
fi

if [ $? -eq 0 ]; then
    echo ""
    echo "Build ARTist succeeded!"
    echo ""
    cd ./app/src/main

    echo "Removing old binaries and shared objects"
    echo ""

    rm ./assets/artist/${api_level_string}/dex2oat
    rm ./assets/artist/${api_level_string}/lib/*.so

    echo "Creating folders if necessary: ./assets/artist/${api_level_string}/lib/"
    mkdir -p ./assets/artist/${api_level_string}/lib/

    echo "Copying new binaries and shared objects"
    echo ""

    if [ "${arch_64}" = true ]; then
        echo "Copy dex2oat (64bit) -> ./assets/artist/${api_level_string}/dex2oat"
        cp ${mounted_aosp}/out/target/product/generic_arm64/symbols/system/bin/dex2oat ./assets/artist/${api_level_string}/dex2oat
    else
        echo "Copy dex2oat (32bit) -> ./assets/artist/${api_level_string}/dex2oat"
        cp ${mounted_aosp}/out/target/product/generic/symbols/system/bin/dex2oat ./assets/artist/${api_level_string}/dex2oat
    fi

    ## now loop through the above array
    for lib in "${dexToOatLibs[@]}"
    do
        if [ "${arch_64}" = true ]; then
            echo "Copy ${lib} (64bit) -> './assets/artist/${api_level_string}/lib/'"
            cp ${mounted_aosp}/out/target/product/generic_arm64/symbols/system/lib/${lib} ./assets/artist/${api_level_string}/lib/
        else
            echo "Copy ${lib} (32bit) -> './assets/artist/${api_level_string}/lib/'"
            cp ${mounted_aosp}/out/target/product/generic/symbols/system/lib/${lib} ./assets/artist/${api_level_string}/lib/
        fi
        if [ "${debug_binaries}" = true ]; then
            echo " > ${lib}: Keeping debug symbols"
        else
        echo " > ${lib}: Stripping debug symbols"
            ${ndk_binary_strip} ./assets/artist/${api_level_string}/lib/${lib}
        fi

    done
    echo ""
    echo "Copying files DONE"

    echo ""
    echo "Saving Git stats"
    git --git-dir ${mounted_art_git_path} --work-tree ${mounted_art_path} log -1 | grep commit > ${art_version_file}
    git --git-dir ${mounted_art_git_path} --work-tree ${mounted_art_path} status --porcelain >> ${art_version_file}

else
    echo "Building ARTist failed..."
fi

echo "" && date
