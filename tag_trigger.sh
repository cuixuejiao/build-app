#!/bin/sh

# check parameters
GERRIT_REFNAME=$1
PROPERTIES_PATH=$2
if [ ! -n "$2" ] ;then
    echo "USAGE: ./tag_trigger.sh GERRIT_REFNAME PROPERTIES_PATH"
    exit 1
fi

# Get the commit id of the trigger ref
mv $PROPERTIES_PATH/tag.properties $PROPERTIES_PATH/tag-old.properties
TAG=`git rev-parse $GERRIT_REFNAME^{commit}`
echo "TAG = $TAG" > $PROPERTIES_PATH/tag.properties

# Fail the build if the commit id did not change
if ! diff -q $PROPERTIES_PATH/tag.properties $PROPERTIES_PATH/tag-old.properties > /dev/null; then
   echo "==============================="
   echo "new commit id, trigger success!"
   echo "==============================="
   exit 0
else
   echo "==============================="
   echo "same commit id, trigger fail!"
   echo "==============================="
   exit 1
fi
