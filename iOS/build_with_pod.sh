#!/bin/bash
#
# Perform iOS app debug build with pods.

#######################################
# faile on each operation and exit 1
# Returns:
#   faile reason
#######################################
function failed() {
    echo "Failed: $@" >&2
    exit 1
}

bash_dir=$(cd $(dirname $0);pwd)
echo "bash_dir = ${bash_dir}"
# read config
. ${bash_dir}/ios_build.config

# open recreate user schemes
/usr/bin/ruby recreate_schemes.rb "${PROJECT_NAME}" \
                                  || failed "recreate user schemes"

# clean
echo "--------------------- CLEAN ---------------------"
/usr/local/bin/xctool clean -scheme ${SCHEME_NAME} \
                            || failed "xctool clean"
# build
echo "--------------------- BUILD ---------------------"
/usr/local/bin/pod install --repo-update
xcodebuild -list -workspace ${PROJECT_NAME}.xcworkspace
/usr/local/bin/xctool build -workspace ${PROJECT_NAME}.xcworkspace \
                            -scheme ${SCHEME_NAME} \
                            CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
                            || failed "xctool build"

echo "Done."
