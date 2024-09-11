rm .\build -Force -Recurse
mkdir build
cd build
cmake .. -G "MinGW Makefiles"
mingw32-make install -j4
cd ..