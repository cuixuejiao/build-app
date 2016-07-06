#!/bin/bash
#
# Perform android aar build and deploy.

#######################################
# faile on each operation and exit 1
# Returns:
#   faile reason
#######################################
function failed() {
    echo "Failed: $@" >&2
    exit 1
}

# check parameters
release_type=$1
if [ "${release_type}" = "release" ]; then
    if [ ! -n "$2" ] ;then
        echo "USAGE: ./package_component_without_doc.sh release_type tag"
        exit 1
    fi
    tag=$2
elif [ "${release_type}" = "snapshot" ]; then
    if [ ! -n "$1" ] ;then
        echo "USAGE: ./package_component_without_doc.sh release_type"
        exit 1
    fi
fi

# read config
bash_dir=$(cd $(dirname $0);pwd)
echo "bash_dir = ${bash_dir}"
. ${bash_dir}/android_build.config

# set artifact name and tag version
echo "ARTIFACT_ID=${ARTIFACT_ID}" > ${MAIN_MODULE}/gradle.properties
if [ "${release_type}" = "release" ]; then
    tag_name=`git describe --tags $tag`
    tag_version=${tag_name%%_*}
    echo "VERSION_NAME=${tag_version}" >> ${MAIN_MODULE}/gradle.properties
elif [ "${release_type}" = "snapshot" ]; then
    echo "VERSION_NAME=${SNAPSHOT_VERSION}" >> ${MAIN_MODULE}/gradle.properties
fi

# clean
echo "--------------------- CLEAN ---------------------"
if [ "${ROOT_PROJECT}" ]; then
    cd ${ROOT_PROJECT}
fi
chmod +x gradlew
./gradlew clean || failed "gradle clean"

# build
string="apply from: '../upload.gradle'"
gradle_file=${bash_dir}/${MAIN_MODULE}/build.gradle
if [ "$(tail -1 ${gradle_file})" != "${string}" ]; then
    echo "" >> ${gradle_file}
    echo ${string} >> ${gradle_file}
fi
echo "--------------------- BUILD ---------------------"
./gradlew build uploadArchives || failed "gradle build"

echo "Done."
