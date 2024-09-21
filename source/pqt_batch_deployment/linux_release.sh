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
line=$(grep -E '^set\(MY_PROJECT_VERSION "[^"]+"\)' CMakeLists.txt)
version=$(echo "$line" | grep -o -E '[0-9]+\.[0-9]+\.[0-9]+')
echo "need build version: ${version}"
source_path=$(pwd)
rm output -rf
mkdir output
mkdir -p output/build
function updateFun(){
    pushd "$2"
    echo "========================================"
    echo "need build $1"
    pwd
    rm build -rf
    mkdir build
    echo "need build version: ${version}"
    pushd build
    cmake .. -DMY_PROJECT_VERSION=${version} -DCMAKE_BUILD_TYPE=Release
    make -j4
    if [ $? -ne 0 ]; then echo "command "${FUNCNAME[1]}" "${BASH_SOURCE[1]}" "$LINENO" error"; exit 1; fi
    make install
    if [ $? -ne 0 ]; then echo "command "${FUNCNAME[1]}" "${BASH_SOURCE[1]}" "$LINENO" error"; exit 1; fi
    cp ./output/* "$source_path/output/build/$1" -a
    if [ $? -ne 0 ]; then echo "command "${FUNCNAME[1]}" "${BASH_SOURCE[1]}" "$LINENO" error"; exit 1; fi
    popd # build
    popd # $2
}
updateFun qt_batch_deployment_no_ui "no_ui" &
updateFun qt_batch_deployment "./" &
wait
if [ $? -ne 0 ]; then echo "command "${FUNCNAME[1]}" "${BASH_SOURCE[1]}" "$LINENO" error"; exit 1; fi
pushd output
pushd build
cp "${source_path}/libs/Appdir" ./ -a
cp ${source_path}/libs/$host_inf/openssl/lib/*.so.* Appdir/usr/lib
cp ${source_path}/libs/$host_inf/release/lib/*.so.* Appdir/usr/lib
find ./ -maxdepth 1 -type f -exec cp {} Appdir/usr/bin \;
sed -i "s/Name=qt_batch_deployment/Name=qt_batch_deployment_${version}/" Appdir/qt_batch_deployment.desktop
mkdir bintools
pushd bintools
cp "${source_path}/libs/$host_inf/appimagetool" ./
chmod +x appimagetool
cp "${source_path}/libs/linuxdeployqt.tar.gz" ./
tar -xaf linuxdeployqt.tar.gz 
pushd linuxdeployqt-continuous
qmake -config release
make -j4
if [ $? -ne 0 ]; then echo "command "${FUNCNAME[1]}" "${BASH_SOURCE[1]}" "$LINENO" error"; exit 1; fi
popd # linuxdeployqt-continuous
popd # bintools
./bintools/linuxdeployqt-continuous/bin/linuxdeployqt Appdir/qt_batch_deployment_no_ui.desktop -appimage -verbose=2
./bintools/linuxdeployqt-continuous/bin/linuxdeployqt Appdir/qt_batch_deployment.desktop -appimage -verbose=2
sed -i "s/Exec=qt_batch_deployment/Exec=qt_batch_deployment_run.sh/" Appdir/qt_batch_deployment.desktop
rm Appdir/qt_batch_deployment_no_ui.desktop
rm Appdir/qt_batch_deployment_no_ui.png
pushd Appdir
rm AppRun
ln -s usr/bin/qt_batch_deployment_run.sh ./AppRun
popd # Appdir
./bintools/appimagetool --comp xz Appdir
if [ $? -ne 0 ]; then echo "command "${FUNCNAME[1]}" "${BASH_SOURCE[1]}" "$LINENO" error"; exit 1; fi
if [ $? -ne 0 ]; then echo "command "${FUNCNAME[1]}" "${BASH_SOURCE[1]}" "$LINENO" error"; return 1; fi
cp ./*.AppImage "${source_path}/output"
if [ $? -ne 0 ]; then echo "command "${FUNCNAME[1]}" "${BASH_SOURCE[1]}" "$LINENO" error"; exit 1; fi
popd # build
popd # output
file_path=$(find "${source_path}/output" -maxdepth 1 -name "qt_batch_deployment*.AppImage" -print -quit)
file_size=$(stat -c %s "$file_path")
file_size_kb=$((file_size / 1024))
if [ $file_size_kb -gt $(( 23 * 1024 )) ]; then
    echo "AppImage size ${file_size_kb}KiB ok"
    exit 0
else
    echo "AppImage size ${file_size_kb}KiB error"
    exit 1
fi 
