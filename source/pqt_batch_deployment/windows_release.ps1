rm .\output -Force -Recurse -ErrorAction SilentlyContinue
mkdir output
$cmd = 'cmake .. -G "MinGW Makefiles"'
Write-Host "cmake cmd: $cmd"

cd no_ui
rm .\build -Force -Recurse -ErrorAction SilentlyContinue
mkdir build
cd build
Invoke-Expression "$cmd"
mingw32-make install -j8
cd ..
cd ..
cp no_ui\build\output\*.7z output

rm .\build -Force -Recurse -ErrorAction SilentlyContinue
mkdir build
cd build
Invoke-Expression "$cmd"
mingw32-make install -j8
cd ..
cp build\output\qt_batch_deployment_V*.exe output
