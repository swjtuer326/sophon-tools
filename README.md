# sophon-tools

## 简介

本工程用于存放算丰设备当前易用性工具源码，便于发版与使用者二次开发

## 目录结构

* `source` 目录下存放各个工具的源码
* `output` 目录下存放编译的最终结果

## 子项目介绍

| 子项目名称 | 源码路径 | 是否支持一键编译 | 简介 |
| --- | --- | --- | --- |
| bmsec      | source/pbmsec | 是 | 用于SE6/8高密度服务器的易用性命令行工具 |
| socbak   | source/psocbak | 是 | 用于BM1684/BM1684X/BM1688/CV186AH芯片刷机包打包 |
| get_info | source/pget_info | 是 | 用于获取BM1684/BM1684X/BM1688/CV186AH芯片的性能指标 |
| memory_edit | source/pmemory_edit | 是 | 用于获取BM1684/BM1684X/BM1688/CV186AH芯片的性能指标 |

## 编译方式

1. 支持一键编译的子项目在本目录下执行 `release.sh` 后会将成果输出到 `output` 目录
2. 不支持一键编译的子项目请参考源码目录中的 `readme.md` 自行准备环境编译

## 一键编译的子项目的编译依赖

* 编译主机架构:amd64
* 7z/zip
* dpkg-deb
* pandoc
