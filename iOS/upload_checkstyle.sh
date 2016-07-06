#!/bin/sh

# check parameters
if [ ! -n "$1" ] ;then
    echo "USAGE: ./upload_checkstyle.sh GERRIT_CHANGE_ID"
    exit 1
fi

if [ -d "checkstyle_dir" ]; then
    rm -fr checkstyle_dir
    mkdir checkstyle_dir
else
    mkdir checkstyle_dir
fi

# get json string:
GERRIT_CHANGE_ID="$1"
ssh -p 29418 jenkins@x.x.x.x gerrit query --files --current-patch-set $GERRIT_CHANGE_ID --format=json > checkstyle_dir/string.json

# delete line 2 to the end (cat xx | wc -l)
sed -i '' '2,$d' checkstyle_dir/string.json

# read filelist by change-id:
cat checkstyle_dir/string.json | /usr/local/bin/jq '.currentPatchSet | .files | map(select(.type != "DELETED")) | .[] | .file' | sed 's/"//g' > checkstyle_dir/filelist
while read ONE_LINE
do
    if [[ ${ONE_LINE} = *"Vendors"* ]] || [[ ${ONE_LINE} = *"ThirdParty"* ]] || [[ ${ONE_LINE} = *"Libraries"* ]] || [[ ${ONE_LINE} = *".framework"* ]]; then
        echo "skip $ONE_LINE"
    elif [ "${ONE_LINE##*.}" = "c" ] || [ "${ONE_LINE##*.}" = "m" ] || [ "${ONE_LINE##*.}" = "mm" ] || [ "${ONE_LINE##*.}" = "h" ]; then
        #cp --parents $ONE_LINE checkstyle_dir
        cp $ONE_LINE checkstyle_dir
    fi
done < checkstyle_dir/filelist

# checkstyle
#cp ~/.clang-format .
RESULT=`ls checkstyle_dir/*.[chm] | xargs /usr/bin/clang-format -style=file -output-replacements-xml | grep -c "<replacement "`
if [ $RESULT -ne 0 ]; then
    echo "===================================================================================================="
    echo "Commit did not match clang-format, please use git commit --amend to modify and push to gerrit again!"
    echo "===================================================================================================="
    exit 1;
fi
