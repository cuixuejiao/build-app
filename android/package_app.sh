#!/bin/bash
#
# Perform android apk build and deploy.

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
if [ ! -n "$2" ] ;then
    echo "USAGE: ./package_app.sh release_type gerrit_change_owner/tag"
    exit 1
fi

release_type=$1
if [ "$release_type" = "release" ]; then
    # get tag info
    tag=$2
    tag_date=`git log -1 --format=%ct $tag`
    tag_name=`git describe --tags $tag`
    prefix=${tag_name%%_*}
    suffix=`date -d @$tag_date +%Y%m%d%H%M%S`
    #suffix=`date -r$tag_date +%Y%m%d%H%M%S`
elif [ "$release_type" = "snapshot" ]; then
    # get gerrit change info
    timestamp=`date "+%Y%m%d%H%M%S"`
    change_owner=$2
fi

bash_dir=$(cd $(dirname $0);pwd)
echo "bash_dir = ${bash_dir}"
# read config
. ${bash_dir}/android_build.config

# clean
echo "--------------------- CLEAN ---------------------"
chmod +x gradlew
./gradlew clean \
       || failed "gradle clean"

# build
echo "--------------------- BUILD ---------------------"
./gradlew ${TASK_NAME} \
       -Pandroid.injected.signing.store.file=${KEYFILE} \
       -Pandroid.injected.signing.store.password=${STORE_PASSWORD} \
       -Pandroid.injected.signing.key.alias=${KEY_ALIAS} \
       -Pandroid.injected.signing.key.password=${KEY_PASSWORD} \
       || failed "gradle ${TASK_NAME}"

# Deploy
echo "--------------------- DEPLOY ---------------------"
# scp .apk to ali apache website
release_dir=/home/jenkins/release_repos/${PROJECT_NAME}/android/${release_type}
if [ "${MAIN_MODULE}" ]; then
    apk_dir=${MAIN_MODULE}/build/outputs/apk
else
    apk_dir=build/outputs/apk
fi
if [ "$release_type" = "release" ]; then
    scp ${apk_dir}/${OLD_NAME}.apk jenkins@x.x.x.x:${release_dir}/${APP_NAME}_${prefix}_${suffix}.apk \
        || failed "scp apk"
elif [ "$release_type" = "snapshot" ]; then
    scp ${apk_dir}/${OLD_NAME}.apk jenkins@x.x.x.x:${release_dir}/${APP_NAME}_${timestamp}_${change_owner}.apk \
        || failed "scp apk"
    # only keep the newest 20 packages(.ipa and .xcarchive)
    ssh jenkins@x.x.x.x /bin/bash <<EOF
cd $RELEASE_DIR && ls -tp | grep -v '/' | tail -n +21 | xargs -I {} rm -- {}
exit
EOF
fi

echo "Done."
