#!/bin/bash
get_arch=$(arch)
host_inf=""
if [[ $get_arch =~ "x86_64" ]];then
    echo "this is x86_64"
    host_inf="linux_amd64"
elif [[ $get_arch =~ "aarch64" ]];then
    echo "this is arm64"
    host_inf="linux_arm64"
elif [[ $get_arch =~ "mips64" ]];then
    echo "this is mips64"
    host_inf=""
else
    echo "unknown!!"
fi
rm build -rf
rm *.AppImage -rf
mkdir build
line=$(grep -E '^set\(MY_PROJECT_VERSION "[^"]+"\)' CMakeLists.txt)
version=$(echo "$line" | grep -o -E '[0-9]+\.[0-9]+\.[0-9]+')
echo "need build version: ${version}"
pushd build
cmake ..
make -j4
make install
pushd output
cp ../../libs/Appdir ./ -a
cp ../../libs/$host_inf/openssl/lib/*.so.* Appdir/usr/lib
cp ../../libs/$host_inf/release/lib/*.so.* Appdir/usr/lib
cp ./qt_mem_edit Appdir/usr/bin
sed -i "s/Name=qt_mem_edit/Name=qt_mem_edit_V${version}/" Appdir/qt_mem_edit.desktop
mkdir bintools
pushd bintools
cp ../../../libs/$host_inf/appimagetool ./
chmod +x appimagetool
# sudo apt-get -y install qt5-default qttools5-dev g++ libgl1-mesa-dev patchelf cmake make gcc
cp ../../../libs/linuxdeployqt.tar.gz ./
tar -xaf linuxdeployqt.tar.gz 
pushd linuxdeployqt-continuous
qmake
make -j4
popd # linuxdeployqt-continuous
popd # bintools
./bintools/linuxdeployqt-continuous/bin/linuxdeployqt Appdir/qt_mem_edit.desktop -appimage -verbose=2
./bintools/appimagetool --comp xz Appdir
cp ./*.AppImage ../../
popd # output
popd # build
# rm build -rf
file_path=$(find . -maxdepth 1 -name '*.AppImage' -print -quit)
if [ -z "$file_path" ]; then
  echo "cannot find AppImage"
  exit -1
fi
file_size=$(stat -c %s "$file_path")
file_size_mb=$((file_size / 1024 / 1024))
if [ $file_size_mb -gt 20 ]; then
  exit 0
else
  echo "AppImage size error"
  exit -1
fi
