# 内存布局修改工具

## 文件解析

``` bash

source
└── memory_edit
    ├── bintools
    │   ├── cpio
    │   ├── dtc
    │   ├── dumpimage
    │   ├── file
    │   └── mkimage
    └── memory_edit.sh

```

* `memory_edit.sh` 文件是主要程序内容
* `bintools` 文件中是编辑itb文件所需要的部分二进制程序

## 使用说明

``` bash

root@bm1684:/data/zzt/new_nfs/memory_edit# ./memory_edit.sh
INFO: version: 2.10
Error: Invalid parameters. Please refer to the following example
/data/zzt/new_nfs/memory_edit/memory_edit.sh -p [dts name] # for print infomation
/data/zzt/new_nfs/memory_edit/memory_edit.sh -c -npu 0x80000000 -vpu 0x80000000 -vpp 0x80000000 [dts name] # for config mem, The memory size unit is Byte
/data/zzt/new_nfs/memory_edit/memory_edit.sh -c -npu 2048 -vpu 2048 -vpp 2048 [dts name] # for config mem, The memory size unit is MiB
for bm1688, please use "memory_edit.sh -c -npu 2048 -vpu 0 -vpp 2048"
/data/zzt/new_nfs/memory_edit/memory_edit.sh -d dtbfile # for de_emmcboot.itb
/data/zzt/new_nfs/memory_edit/memory_edit.sh -e dtbfile # for en_emmcboot.itb
/data/zzt/new_nfs/memory_edit/memory_edit.sh --clean # clean this dir

```

### ramdisk编辑功能说明

在执行`-d`前，使用`export MEMORY_EDIT_RAMDISK=1`配置环境变量，此时会在`output/ramdisk`下生成`ramdisk`中的文件

在执行`-e`前，使用`export MEMORY_EDIT_RAMDISK=1`配置环境变量，此时会将`output/ramdisk`下的文件打包到itb中的ramdisk中

