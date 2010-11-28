#!/bin/sh

                 FRAMEWORK_NAME=BsonNetwork
              FRAMEWORK_VERSION=A
      FRAMEWORK_CURRENT_VERSION=1
FRAMEWORK_COMPATIBILITY_VERSION=1
                     BUILD_TYPE=Release

FRAMEWORK_BUILD_PATH="build/Framework/"
FRAMEWORK_DIR="$FRAMEWORK_BUILD_PATH/$FRAMEWORK_NAME.framework"
FRAMEWORK_TARBALL="release/$FRAMEWORK_NAME.tar.gz"

echo "Framework: cleaning framework destination..."
rm -rf $FRAMEWORK_DIR/*
# IMPORTANT NOTE: remove $FRAMEWORK_DIR/* and not $FRAMEWORK_DIR in order
#                 to preserve directory links from other projects!
#

# Build the canonical Framework bundle directory structure
echo "Framework: setting up directories..."
mkdir -p $FRAMEWORK_DIR
mkdir -p $FRAMEWORK_DIR/Versions
mkdir -p $FRAMEWORK_DIR/Versions/$FRAMEWORK_VERSION
mkdir -p $FRAMEWORK_DIR/Versions/$FRAMEWORK_VERSION/Resources
mkdir -p $FRAMEWORK_DIR/Versions/$FRAMEWORK_VERSION/Headers

echo "Framework: creating symlinks..."
ln -s $FRAMEWORK_VERSION $FRAMEWORK_DIR/Versions/Current
ln -s Versions/Current/Headers $FRAMEWORK_DIR/Headers
ln -s Versions/Current/Resources $FRAMEWORK_DIR/Resources
ln -s Versions/Current/$FRAMEWORK_NAME $FRAMEWORK_DIR/$FRAMEWORK_NAME

# Check that this is what your static libraries are called
FRAMEWORK_INPUT_ARM_FILES="build/$BUILD_TYPE-iphoneos/lib$FRAMEWORK_NAME.a"
FRAMEWORK_INPUT_I386_FILES="build/$BUILD_TYPE-iphonesimulator/lib$FRAMEWORK_NAME.a"

# to use lipo to glue the different library versions together into one library
echo "Framework: creating library..."
lipo \
  -create \
  "$FRAMEWORK_INPUT_ARM_FILES" \
  -arch i386 "$FRAMEWORK_INPUT_I386_FILES" \
  -o "$FRAMEWORK_DIR/Versions/Current/$FRAMEWORK_NAME"

if [ $? -ne 0 ];then
  echo "error: failed to create library. (uses Release build)"
  exit
fi

# Copy resources
echo "Framework: copying assets..."
cp Resources/Framework.plist $FRAMEWORK_DIR/Resources/Info.plist

cp src/*.h $FRAMEWORK_DIR/Headers/
cp lib/bson-objc/BSONCodec.h $FRAMEWORK_DIR/Headers/
cp lib/cas/AsyncSocket.h $FRAMEWORK_DIR/Headers/

# Package up
echo "Framework: packaging tarball..."
cd $FRAMEWORK_BUILD_PATH
tar -czf $FRAMEWORK_NAME.tar.gz $FRAMEWORK_NAME.framework
cd ../../
mv $FRAMEWORK_BUILD_PATH$FRAMEWORK_NAME.tar.gz $FRAMEWORK_TARBALL

# Done :)
echo "Framework: all done!"
