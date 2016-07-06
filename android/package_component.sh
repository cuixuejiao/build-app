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
        echo "USAGE: ./package_component.sh release_type tag"
        exit 1
    fi
    tag=$2
elif [ "${release_type}" = "snapshot" ]; then
    if [ ! -n "$1" ] ;then
        echo "USAGE: ./package_component.sh release_type"
        exit 1
    fi
fi

# read config
bash_dir=$(cd $(dirname $0);pwd)
echo "bash_dir = ${bash_dir}"
. ${bash_dir}/android_build.config

# set artifact name and tag version
echo "MAIN_MODULE=${MAIN_MODULE}" > ${MAIN_MODULE}/gradle.properties
echo "ARTIFACT_ID=${ARTIFACT_ID}" >> ${MAIN_MODULE}/gradle.properties
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
if [ "${release_type}" = "snapshot" ]; then
    echo "--------------------- BUILD ---------------------"
    ./gradlew build || failed "gradle build"
    echo "------------------ PUBLISH AAR ------------------"
    ./gradlew publish || failed "gradle publish"
elif [ "${release_type}" = "release" ]; then
    echo "--------------------- BUILD ---------------------"
    ./gradlew build -Pandroid.injected.signing.store.file=${KEYFILE} \
                    -Pandroid.injected.signing.store.password=${STORE_PASSWORD} \
                    -Pandroid.injected.signing.key.alias=${KEY_ALIAS} \
                    -Pandroid.injected.signing.key.password=${KEY_PASSWORD} \
                    || failed "gradle build"
    echo "--------------- GENERATE JAVA DOC ---------------"
    ./gradlew generateReleaseJavadoc || failed "gradle generate release javadoc"
    echo "------------------ PUBLISH AAR ------------------"
    ./gradlew publish || failed "gradle publish"

    # build results
    mapping_dir=${bash_dir}/${ARTIFACT_ID}/build/outputs/mapping/release
    javadoc_dir=${bash_dir}/${ARTIFACT_ID}/build/docs/javadoc
    if [ "${ROOT_PROJECT}" ]; then
        apk_dir=${bash_dir}/${ROOT_PROJECT}/app/build/outputs/apk
    else
        apk_dir=${bash_dir}/app/build/outputs/apk
    fi

    # create deploy dir with tag info
    deploy_dir=/home/smarthome/component
    gitbook_dest=${deploy_dir}/release/${ARTIFACT_ID}/android/${tag_version}
    if [ -d "${gitbook_dest}" ]; then
        rm -fr ${gitbook_dest}
    fi
    mkdir -p ${gitbook_dest}

    #
    # deploy gitbook
    echo "--------------- GENERATE GITBOOK ----------------"
    # create temp dir to generate gitbook
    gitbook_dir=${bash_dir}/gitbook
    if [ -d "${gitbook_dir}" ]; then
        rm -fr ${gitbook_dir}
    fi
    mkdir -p ${gitbook_dir}
    # copy javadoc
    if [ -d "${bash_dir}/Public/API/${ARTIFACT_ID}" ]; then
        rm -fr ${bash_dir}/Public/API/${ARTIFACT_ID}
    fi
    mkdir -p ${bash_dir}/Public/API/${ARTIFACT_ID}
    cp -r ${javadoc_dir}/* ${bash_dir}/Public/API/${ARTIFACT_ID}
    # copy apk
    cp ${apk_dir}/app-release.apk ${bash_dir}/Public/Resource/${ARTIFACT_ID}Debugger.apk
    # copy Public dir
    cp -r ${bash_dir}/Public ${gitbook_dir}
    # copy md files
    cp ${bash_dir}/readme.md ${gitbook_dir}
    cp ${bash_dir}/summary.md ${gitbook_dir}
    gitbook build ${gitbook_dir} || failed "generate gitbook"
    echo "---------------- DEPLOY GITBOOK -----------------"
    cp -r ${gitbook_dir}/_book/* ${gitbook_dest}
    # link "current" (symbole link) to latest version
    cd ${deploy_dir}/release/${ARTIFACT_ID}/android
    rm current
    ln -s ${tag_version} current

    #
    # deploy mapping files
    echo "------------- DEPLOY MAPPING FILE ---------------"
    mapping_dest=${deploy_dir}/mapping/${ARTIFACT_ID}/android/${tag_version}/${tag_name}
    if [ -d "${mapping_dest}" ]; then
        rm -fr ${mapping_dest}
    fi
    mkdir -p ${mapping_dest}
    cp -r ${mapping_dir}/* ${mapping_dest}
fi

echo "Done."
