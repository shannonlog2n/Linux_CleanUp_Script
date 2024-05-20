#!/bin/bash

# 确保脚本以root权限运行
if [[ $EUID -ne 0 ]]; then
   echo "此脚本必须以root权限运行" 
   exit 1
fi

start_space=$(df --block-size=1M / | tail -n 1 | awk '{print $4}')

# 检测操作系统类型
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$NAME"
    elif [ -f /etc/centos-release ]; then
        echo "CentOS"
    elif [ -f /etc/debian_version ]; then
        echo "Debian"
    elif [ -f /etc/alpine-release ]; then
        echo "Alpine"
    else
        echo "Unknown"
    fi
}

OS=$(detect_os)

# 更新依赖并安装必要工具
install_tools() {
    case $OS in
        "Debian"|"Ubuntu")
            if ! dpkg -l | grep -qw deborphan; then
                apt-get update && apt-get install -y deborphan
            fi
            ;;
        "CentOS"|"Red Hat"|"Fedora")
            yum update -y && yum install -y yum-utils
            ;;
        "Alpine")
            apk update && apk add --no-cache alpine-sdk
            ;;
    esac
}

install_tools

# 安全删除旧内核
remove_old_kernels() {
    local current_kernel=$(uname -r)
    case $OS in
        "Debian"|"Ubuntu")
            local kernel_packages=$(dpkg --list | grep -E '^ii  linux-(image|headers)-[0-9]+' | awk '{ print $2 }' | grep -v "$current_kernel")
            if [ -n "$kernel_packages" ]; then
                echo "找到旧内核，正在删除：$kernel_packages"
                apt-get purge -y $kernel_packages && update-grub
            else
                echo "没有旧内核需要删除。"
            fi
            ;;
        "CentOS"|"Red Hat"|"Fedora")
            package-cleanup --oldkernels --count=1
            ;;
        "Alpine")
            echo "Alpine Linux 不需要手动清理旧内核。"
            ;;
    esac
}

remove_old_kernels

# 清理系统日志文件
clean_logs() {
    echo "正在清理系统日志文件..."
    find /var/log -type f -name "*.log" -exec truncate -s 0 {} \;
    find /root -type f -name "*.log" -exec truncate -s 0 {} \;
    find /home -type f -name "*.log" -exec truncate -s 0 {} \;
    find /ql -type f -name "*.log" -exec truncate -s 0 {} \;
}

clean_logs

# 清理缓存目录
clean_cache() {
    echo "正在清理缓存目录..."
    find /tmp -type f -mtime +1 -exec rm -f {} \;
    find /var/tmp -type f -mtime +1 -exec rm -f {} \;
    for user in /home/* /root; do
        cache_dir="$user/.cache"
        if [ -d "$cache_dir" ]; then
            rm -rf "$cache_dir"/*
        fi
    done
}

clean_cache

# 清理Docker（如果使用Docker）
clean_docker() {
    if command -v docker &> /dev/null; then
        echo "正在清理Docker镜像、容器和卷..."
        docker system prune -a -f --volumes
    fi
}

clean_docker

# 清理孤立包和包管理器缓存
clean_packages() {
    echo "正在清理孤立包和包管理器缓存..."
    case $OS in
        "Debian"|"Ubuntu")
            deborphan --guess-all | xargs -r apt-get -y remove --purge
            apt-get autoremove -y && apt-get clean
            ;;
        "CentOS"|"Red Hat"|"Fedora")
            package-cleanup --leaves | xargs -r yum remove -y
            yum autoremove -y && yum clean all
            ;;
        "Alpine")
            apk cache clean
            ;;
    esac
}

clean_packages

end_space=$(df --block-size=1M / | tail -n 1 | awk '{print $4}')
cleared_space=$((start_space - end_space))
echo "系统清理完成，清理了 ${cleared_space}M 空间！"
