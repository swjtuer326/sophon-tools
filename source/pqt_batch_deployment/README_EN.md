# Batch deployment tool
### 1. Linux
##### 1.1 Environment configuration
The dependencies that need to be installed are as follows:：
qt5-default qttools5-dev git g++ libgl1-mesa-dev patchelf fuse  

##### 1.2 Perform compilation
There are two script files linux_docker.sh and linux_release.sh in the directory;
Users can directly run the script file for compilation. 
Currently, it is recommended to use the linux_docker.sh file for compilation;
After the compilation and execution is completed, the output folder will be generated, and there is the qt_batch_deployment_Vxxx.AppImage file under the folder;

##### 1.3 Running
The program running command are as follows
./qt_batch_deployment_Vxxx.AppImage [Root Directory] [Json File Path] [Max Value]  
Root Directory, Json File Path, and Max Value are optional parameters;

##### 1.3.1 Graphical interface mode
When the Root Directory, Json File Path, and Max Value parameters are not entered, the graphical interface mode will be started;

##### 1.3.2 Command line mode
When the Root Directory, Json File Path, and Max Value parameters are entered, the command line mode will be started;  
Root Directory：The command line mode runs the root directory. Other relative paths will use this path as the main directory and need to be absolute paths;
Json File Path：The path where the configuration file is located needs to be an absolute path;
Max Value：Maximum number of parallel operations, default is 100;

### 2. Windows
##### 2.1 Environment configuration
Configure the qt basic environment in windows, and add the paths of cmake and mingw64 that come with qt to the system variables;  
Add a directory similar to C:/Qt/5.15.2/mingw81_64 to the environment variable of QT_PLATFORM_DIR;  
Add a directory similar to C:/Qt/Tools/mingw810_64/bin to the environment variable of QT_GCC_PLATFORM_DIR  

##### 2.2 Perform compilation
There is a windows_release.ps1 script file in the directory； 
Run the windows_release.ps1 script file to compile；
After compilation is completed, two files, qt_batch_deployment_Vxxx.exe and qt_batch_deployment_Vxxx.7z, will be generated.；
qt_batch_deployment_Vxxx.exe is a graphical mode application；
Unzip qt_batch_deployment_Vxxx.7z, where qt_batch_deployment_no_ui.exe is the command line mode application；

##### 2.3 Running
##### 1.3.1 Graphical interface mode
Double-click qt_batch_deployment_Vxxx.exe to start the graphical mode;

##### 1.3.2 Command line mode
Use cmd or powershell in command line mode to run the qt_batch_deployment_no_ui.exe file;
The running instructions are as follows：
./qt_batch_deployment_no_ui.exe [Root Directory] [Json File Path] [Max Value]
Root Directory, Json File Path, and Max Value are the parameters that need to be added;  
Root Directory：The command line mode runs the root directory. Other relative paths will use this path as the main directory and need to be absolute paths;
Json File Path：The path where the configuration file is located needs to be an absolute path;
Max Value：Maximum number of parallel operations, default is 100;
