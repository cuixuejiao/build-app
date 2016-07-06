#!/bin/bash
#
# Perform code style check for gerrit changes.

# check parameters
change_id=$1
if [ ! -n "$1" ] ;then
    echo "USAGE: ./upload_checkstyle.sh GERRIT_CHANGE_ID"
    exit 1
fi

bash_dir=$(cd $(dirname $0);pwd)
echo "bash_dir = ${bash_dir}"

# make dir for checkstyle results
result_dir=${bash_dir}/checkstyle_dir
if [ -d "${result_dir}" ]; then
    rm -fr ${result_dir}
fi
mkdir ${result_dir}

# query gerrit change
ssh -p 29418 jenkins@xxx.xxx.xx.xx gerrit query \
                                   --files \
                                   --current-patch-set ${change_id} \
                                   --format=json > ${result_dir}/string.json
sed -i '2,$d' ${result_dir}/string.json
cat ${result_dir}/string.json \
    | jq '.currentPatchSet | .files | map(select(.type != "DELETED")) | .[] | .file' \
    | sed 's/"//g' > ${result_dir}/filelist

# checkstyle
java -jar ${bash_dir}/my_cs.jar \
     -j /home/checkstyle/checkstyle.jar \
     -p ${bash_dir} \
     -o ${bash_dir} \
     -mr ${bash_dir}/checkstyle.xml \
     -tr ${bash_dir}/checkstyle_test.xml \
     -l ${result_dir}/filelist \
     -e xckevin/,third/,xxx/util/AesCbcWithIntegrity.java

echo "done."
