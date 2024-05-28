# Debian_CleanUp_Script

## 简介
Linux_CleanUp_Script 是一个专为Linux服务器设计的 Bash 脚本，专注于系统维护，通过清理不必要的文件和组件来优化系统性能。

## 功能
- 清理未使用的内核
- 清理系统日志文件
- 清理用户和系统缓存目录
- 清理 Docker 镜像、容器和卷
- 清理孤立的软件包
- 清理包管理器缓存
- 显示清理前后的空间差异

## 使用说明

### 权限要求
此脚本必须以 `root` 权限运行。

### 运行脚本
在终端运行以下命令：
```bash
bash <(curl -s https://raw.githubusercontent.com/shannonlog2n/Linux_CleanUp_Script/main/server_cleanup.sh)
