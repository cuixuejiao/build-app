#!/bin/bash
#
# Perform android checkstyle, build and findbugs.

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
build_type=$1
if [ ! -n "$1" ] ;then
    echo "USAGE: ./quality.sh daily"
    echo "---- or ----"
    echo "USAGE: ./quality.sh upload"
    exit 1
fi

# read config
bash_dir=$(cd $(dirname $0);pwd)
echo "bash_dir = ${bash_dir}"
. ${bash_dir}/android_build.config

# add dependencies for check
STRING="apply from: '../quality.gradle'"
for module in `echo ${MODULES} | sed 's/,/ /g'`
do
    gradle_file=${module}/build.gradle
    if [ "$(tail -1 ${gradle_file})" != "${STRING}" ]; then
        echo "" >> ${gradle_file}
        echo ${STRING} >> ${gradle_file}
    fi
done

# build
chmod +x gradlew
if [ ${build_type} = "daily" ]; then
    ./gradlew clean checkstyle ${TASK_NAME} findbugs  || failed "gradle"
elif [ ${build_type} = "upload" ]; then
    ./gradlew ${TASK_NAME} findbugs  || failed "gradle"
fi

echo "done."
