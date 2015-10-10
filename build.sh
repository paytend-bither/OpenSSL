#!/bin/bash

# This script downlaods and builds the iOS and Mac openSSL libraries with Bitcode enabled

# Credits:
# https://github.com/st3fan/ios-openssl
# https://github.com/x2on/OpenSSL-for-iPhone/blob/master/build-libssl.sh
# Peter Steinberger, PSPDFKit GmbH, @steipete.

set -e

SDK_VERSION="9.0"
MIN_SDK_VERSION="7.0"

OPENSSL_VERSION="openssl-1.0.1j"
DEVELOPER=`xcode-select -print-path`

buildMac()
{
   ARCH=$1

   echo "Building ${OPENSSL_VERSION} for ${ARCH}"

   TARGET="darwin-i386-cc"

   if [[ $ARCH == "x86_64" ]]; then
      TARGET="darwin64-x86_64-cc"
   fi

   export CC="${BUILD_TOOLS}/usr/bin/clang -fembed-bitcode"

   pushd . > /dev/null
   cd "${OPENSSL_VERSION}"
   ./Configure no-asm ${TARGET} --openssldir="/tmp/${OPENSSL_VERSION}-${ARCH}" &> "/tmp/${OPENSSL_VERSION}-${ARCH}.log"
   make >> "/tmp/${OPENSSL_VERSION}-${ARCH}.log" 2>&1
   make install >> "/tmp/${OPENSSL_VERSION}-${ARCH}.log" 2>&1
   make clean >> "/tmp/${OPENSSL_VERSION}-${ARCH}.log" 2>&1
   popd > /dev/null
}

buildIOS()
{
   ARCH=$1

   pushd . > /dev/null
   cd "${OPENSSL_VERSION}"
  
   if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]]; then
      PLATFORM="iPhoneSimulator"
   else
      PLATFORM="iPhoneOS"
      sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" "crypto/ui/ui_openssl.c"
   fi
  
   export $PLATFORM
   export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
   export CROSS_SDK="${PLATFORM}${SDK_VERSION}.sdk"
   export BUILD_TOOLS="${DEVELOPER}"
   export CC="${BUILD_TOOLS}/usr/bin/gcc -fembed-bitcode -arch ${ARCH}"
   
   echo "Building ${OPENSSL_VERSION} for ${PLATFORM} ${SDK_VERSION} ${ARCH}"

   if [[ "${ARCH}" == "x86_64" ]]; then
      ./Configure no-asm darwin64-x86_64-cc --openssldir="/tmp/${OPENSSL_VERSION}-iOS-${ARCH}" &> "/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log"
   else
      ./Configure iphoneos-cross --openssldir="/tmp/${OPENSSL_VERSION}-iOS-${ARCH}" &> "/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log"
   fi
   # add -isysroot to CC=
   sed -ie "s!^CFLAG=!CFLAG=-isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min=${MIN_SDK_VERSION} !" "Makefile"

   make >> "/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log" 2>&1
   make install >> "/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log" 2>&1
   make clean >> "/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log" 2>&1
   popd > /dev/null
}

echo "Cleaning up"
rm -rf /tmp/${OPENSSL_VERSION}-*
rm -rf ${OPENSSL_VERSION}
rm -rf include-ios/openssl/* include-osx/openssl/* lib-ios/* lib-osx/*

mkdir -p lib-ios
mkdir -p lib-osx
mkdir -p include-ios/openssl/
mkdir -p include-osx/openssl/

rm -rf "/tmp/${OPENSSL_VERSION}-*"
rm -rf "/tmp/${OPENSSL_VERSION}-*.log"

rm -rf "${OPENSSL_VERSION}"

if [ ! -e ${OPENSSL_VERSION}.tar.gz ]; then
   echo "Downloading ${OPENSSL_VERSION}.tar.gz"
   curl -O http://www.openssl.org/source/${OPENSSL_VERSION}.tar.gz
else
   echo "Using ${OPENSSL_VERSION}.tar.gz"
fi

echo "Unpacking openssl"
tar xfz "${OPENSSL_VERSION}.tar.gz"

buildMac "x86_64"

echo "Copying headers"
cp /tmp/${OPENSSL_VERSION}-x86_64/include/openssl/* include-osx/openssl/

echo "Building Mac libraries"
lipo \
   "/tmp/${OPENSSL_VERSION}-x86_64/lib/libcrypto.a" \
   -create -output lib-osx/libcrypto.a

lipo \
   "/tmp/${OPENSSL_VERSION}-x86_64/lib/libssl.a" \
   -create -output lib-osx/libssl.a

buildIOS "armv7"
buildIOS "arm64"
buildIOS "x86_64"
buildIOS "i386"

echo "Copying headers"
cp /tmp/${OPENSSL_VERSION}-iOS-armv7/include/openssl/* include-ios/openssl/

echo "Building iOS libraries"
lipo \
   "/tmp/${OPENSSL_VERSION}-iOS-armv7/lib/libcrypto.a" \
   "/tmp/${OPENSSL_VERSION}-iOS-i386/lib/libcrypto.a" \
   -create -output lib-ios/libcrypto.a

lipo \
   "/tmp/${OPENSSL_VERSION}-iOS-armv7/lib/libssl.a" \
   "/tmp/${OPENSSL_VERSION}-iOS-i386/lib/libssl.a" \
   -create -output lib-ios/libssl.a

   echo "Adding 64-bit libraries"
   lipo \
      "lib-ios/libcrypto.a" \
      "/tmp/${OPENSSL_VERSION}-iOS-arm64/lib/libcrypto.a" \
      "/tmp/${OPENSSL_VERSION}-iOS-x86_64/lib/libcrypto.a" \
      -create -output lib-ios/libcrypto.a

   lipo \
      "lib-ios/libssl.a" \
      "/tmp/${OPENSSL_VERSION}-iOS-arm64/lib/libssl.a" \
      "/tmp/${OPENSSL_VERSION}-iOS-x86_64/lib/libssl.a" \
      -create -output lib-ios/libssl.a

echo "Cleaning up"
rm -rf /tmp/${OPENSSL_VERSION}-*
rm -rf ${OPENSSL_VERSION}

echo "Done"
