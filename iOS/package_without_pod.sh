#!/bin/bash
#
# Perform iOS app archive without pods.

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
    echo "USAGE: ./package_without_pod.sh release_type gerrit_change_owner/tag"
    exit 1
fi

release_type=$1
if [ "$release_type" = "release" ]; then
    # get tag info
    tag=$2
    tag_date=`git log -1 --format=%ct $tag`
    tag_name=`git describe --tags $tag`
    prefix=${tag_name%%_*}
    #suffix=`date -d @$tag_date +%Y%m%d%H%M%S`
    suffix=`date -r$tag_date +%Y%m%d%H%M%S`
elif [ "$release_type" = "snapshot" ]; then
    # get gerrit change info
    timestamp=`date "+%Y%m%d%H%M%S"`
    change_owner=$2
fi

LOGIN_KEYCHAIN=~/Library/Keychains/login.keychain

bash_dir=$(cd $(dirname $0);pwd)
echo "bash_dir = ${bash_dir}"
# read config
. ${bash_dir}/ios_build.config

# unlock login keygen
security unlock-keychain -p ${LOGIN_PASSWORD} ${LOGIN_KEYCHAIN} || failed "unlock-keygen"

# open recreate user schemes
/usr/bin/ruby recreate_schemes.rb "${PROJECT_NAME}" \
                                  || failed "recreate user schemes"

# clean
echo "--------------------- CLEAN ---------------------"
rm -fr ${bash_dir}/build
xcodebuild clean -project ${PROJECT_NAME}.xcodeproj \
                 -configuration ${CONFIGURATION} \
                 -alltargets \
                 || failed "xcodebuild clean"
# archive
echo "--------------------- BUILD ---------------------"
xcodebuild archive -project ${PROJECT_NAME}.xcodeproj \
                   -scheme ${SCHEME_NAME} \
                   -sdk iphoneos \
                   -configuration ${CONFIGURATION} \
                   -archivePath ${bash_dir}/build/${PROJECT_NAME}.xcarchive \
                   CODE_SIGN_IDENTITY="${IDENTITY}" PROVISIONING_PROFILE="${UUID}" \
                   || failed "xcodebuild archive"

# export ipa
echo "--------------------- PACKAGE ---------------------"
xcodebuild -exportArchive -archivePath ${bash_dir}/build/${PROJECT_NAME}.xcarchive \
                          -exportPath ${bash_dir}/build/ \
                          -exportOptionsPlist ${bash_dir}/exportOptions.plist \
                          -verbose \
                          || failed "xcodebuild export archive"

# Deploy
echo "--------------------- DEPLOY ---------------------"
# scp .ipa and .archive to ali apache website
release_dir=/home/jenkins/release_repos/${RELEASE_FOLDER_NAME}/iOS/${release_type}
cd ${bash_dir}/build
zip -r ${PROJECT_NAME}.xcarchive.zip ${PROJECT_NAME}.xcarchive

if [ "$release_type" = "release" ]; then
    scp ${PROJECT_NAME}.ipa jenkins@x.x.x.x:${release_dir}/${APP_NAME}_${prefix}_${suffix}.ipa \
        || failed "scp ipa"
    scp ${PROJECT_NAME}.xcarchive.zip jenkins@x.x.x.x:${release_dir}/${APP_NAME}_${prefix}_${suffix}.xcarchive.zip \
        || failed "scp xcarchive"
elif [ "$release_type" = "snapshot" ]; then
    scp ${PROJECT_NAME}.ipa jenkins@x.x.x.x:${release_dir}/${APP_NAME}_${timestamp}_${change_owner}.ipa \
        || failed "scp ipa"
    scp ${PROJECT_NAME}.xcarchive.zip jenkins@x.x.x.x:${release_dir}/${APP_NAME}_${timestamp}_${change_owner}.xcarchive.zip \
        || failed "scp xcarchive"
    # only keep the newest 20 packages(.ipa and .xcarchive)
    ssh jenkins@x.x.x.x /bin/bash <<EOF
cd $RELEASE_DIR && ls -tp | grep -v '/' | tail -n +41 | xargs -I {} rm -- {}
exit
EOF
fi

echo "Done."
