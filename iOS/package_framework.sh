#!/bin/bash
#
# Perform iOS framework build

#######################################
# fail on each operation and exit 1
# Returns:
#   fail reason
#######################################
function failed() {
    echo "Failed: $@" >&2
    exit 1
}

# check parameters
ci_workspace=$1
tag=$2
if [ ! -n "$2" ] ;then
    echo "USAGE: ./package_framework.sh ci_workspace tag"
    exit 1
fi

# get tag info
tag_name=`git describe --tags $tag`
tag_version=${tag_name%%_*}

# read config
bash_dir=$(cd $(dirname $0);pwd)
echo "bash_dir = ${bash_dir}"
. ${bash_dir}/ios_build.config

# unlock login keygen
LOGIN_KEYCHAIN=~/Library/Keychains/login.keychain
security unlock-keychain -p ${LOGIN_PASSWORD} ${LOGIN_KEYCHAIN} || failed "unlock-keygen"

# open recreate user schemes
/usr/bin/ruby recreate_schemes.rb "${PROJECT_NAME}" \
                                 || failed "recreate user schemes"

# clean
echo "--------------------- CLEAN ---------------------"
rm -fr build
xcodebuild clean -project ${PROJECT_NAME}.xcodeproj \
                 -configuration ${CONFIGURATION} \
                 -alltargets \
                 || failed "xcodebuild clean"

# build
echo "--------------------- BUILD ---------------------"
/usr/local/bin/pod install --repo-update
xcodebuild -list -workspace ${PROJECT_NAME}.xcworkspace
xcodebuild build -workspace ${PROJECT_NAME}.xcworkspace \
                 -scheme ${LIB_SCHEME_NAME} \
                 -configuration ${CONFIGURATION} \
                 -sdk iphonesimulator ONLY_ACTIVE_ARCH=NO \
                 -destination 'platform=iOS Simulator,name=iPhone 6' \
                 -derivedDataPath build \
                 || failed "xcodebuild build iphonesimulator"
xcodebuild build -workspace ${PROJECT_NAME}.xcworkspace \
                 -scheme ${LIB_SCHEME_NAME} \
                 -configuration ${CONFIGURATION} \
                 -sdk iphoneos ONLY_ACTIVE_ARCH=NO \
                 -derivedDataPath build \
                 CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
                 || failed "xcodebuild build iphoneos"

# recreate framework
echo "-------------- RECREATE FRAMEWORK ---------------"
# build results dir
simulator_dir=build/Build/Products/Release-iphonesimulator/${LIB_SCHEME_NAME}.framework
device_dir=build/Build/Products/Release-iphoneos/${LIB_SCHEME_NAME}.framework

# new dir for final output
framework_dir=${LIB_SCHEME_NAME}.framework
if [ -d "${framework_dir}" ]; then
    rm -rf ${framework_dir}
fi
mkdir ${framework_dir}

# merge binary files
/usr/bin/lipo -create ${device_dir}/${LIB_SCHEME_NAME} ${simulator_dir}/${LIB_SCHEME_NAME} \
              -output ${framework_dir}/${LIB_SCHEME_NAME} \
              || failed "lipo merge framework"
echo "recreate framework dir: ${framework_dir}"

# copy headers and resources files (device and simulator are the same)
cp -R ${device_dir}/Headers ${framework_dir}
cp ${device_dir}/Info.plist ${framework_dir}
tar -cf ${framework_dir}.tar ${framework_dir} || failed "tar framework"

# create temp dir to save api docs for current version
publish_dir=${bash_dir}/genrate_docs/${ARTIFACT_NAME}/iOS/${tag_version}
if [ -d "${publish_dir}" ]; then
    rm -fr ${publish_dir}
fi
mkdir -p ${publish_dir}

# create temp dir to genrate gitbook
gitbook_dir=${bash_dir}/gitbook
if [ -d "${gitbook_dir}" ]; then
    rm -fr ${gitbook_dir}
fi
mkdir -p ${gitbook_dir}
cp -r ${bash_dir}/Public ${gitbook_dir}
cp ${bash_dir}/readme.md ${gitbook_dir}
cp ${bash_dir}/summary.md ${gitbook_dir}

# genrate appledoc
echo "-------------- GENERATE APPLEDOC ----------------"
/usr/local/bin/appledoc --no-create-docset \
                        --output ${gitbook_dir}/Public/API \
                        --project-name ${ARTIFACT_NAME} \
                        --company-id "com.haierubic" \
                        --project-company "Haierubic" \
                        --project-version ${tag_version} \
                        ${framework_dir}/Headers \
                        || failed "genrate appledoc"

# genrate gitbook
echo "--------------- GENERATE GITBOOK ----------------"
/usr/local/bin/gitbook -v 2.6.7 build ${gitbook_dir} \
                                      || failed "genrate gitbook"
mv ${gitbook_dir}/_book/* ${publish_dir}

# tar API doc
cd ${bash_dir}/genrate_docs
tar -cf genrate_docs.tar ${ARTIFACT_NAME} || failed "tar API docs"
cd ${bash_dir}

echo "--------------- DEPLOY FRAMEWORK ----------------"
# make tar and move to pod repository
deploy_dir=${WORKSPACE}/${POD_PROJECT_NAME}/${tag_version}
if [ -d "${deploy_dir}" ]; then
    rm -fr ${deploy_dir}
fi
mkdir ${deploy_dir}
cp -fr ${framework_dir}.tar ${deploy_dir} || failed "move framework tar"
cd ${deploy_dir} && tar -xf ${framework_dir}.tar || failed "extract framework tar"
rm ${framework_dir}.tar
git add .
git commit -m "[Feature]auto deploy framework: ${LIB_SCHEME_NAME}, ${tag_version}"
git push origin HEAD:master || failed "git push framework"
git reset --hard;git clean -dfx

echo "---------------- DEPLOY PODSPECS ----------------"
# copy podspec file to spec repository
spec_dir=${WORKSPACE}/CocoaPods/Specs/${ARTIFACT_NAME}/${tag_version}
if [ -d "${spec_dir}" ]; then
    rm -fr ${spec_dir}
fi
mkdir -p ${spec_dir}
cp -fr ${bash_dir}/${ARTIFACT_NAME}.podspec ${spec_dir} || failed "copy spec tar"
cd ${spec_dir}
git add .
git commit -m "[Feature]auto deploy spec file: ${LIB_SCHEME_NAME}, ${tag_version}"
git push origin HEAD:master || failed "git push spec file"
git reset --hard;git clean -dfx

echo "Done."
