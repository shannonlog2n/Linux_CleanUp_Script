#!/bin/bash

# 确保脚本以root权限运行
if [[ $EUID -ne 0 ]]; then
   echo "此脚本必须以root权限运行" 
   exit 1
fi

start_space=$(df / | tail -n 1 | awk '{print $3}')

# 正在更新依赖
echo "正在更新依赖..."
if [ ! -x /usr/bin/deborphan ]; then
    apt-get update > /dev/null 2>&1
    apt-get install -y deborphan > /dev/null 2>&1
fi

# 安全删除旧内核
echo "正在删除未使用的内核..."
current_kernel=$(uname -r)
kernel_packages=$(dpkg --list | grep -E '^ii  linux-(image|headers)-[0-9]+' | awk '{ print $2 }' | grep -v "$current_kernel")
if [ ! -z "$kernel_packages" ]; then
    echo "找到旧内核，正在删除：$kernel_packages"
    apt-get purge -y $kernel_packages > /dev/null 2>&1
    update-grub  > /dev/null 2>&1
else
    echo "没有旧内核需要删除。"
fi

# 清理系统日志文件
echo "正在清理系统日志文件..."
find /var/log -type f -name "*.log" -exec truncate -s 0 {} \; > /dev/null 2>&1
find /root -type f -name "*.log" -exec truncate -s 0 {} \; > /dev/null 2>&1
find /home -type f -name "*.log" -exec truncate -s 0 {} \; > /dev/null 2>&1

# 清理缓存目录
echo "正在清理缓存目录..."
find /tmp -type f -mtime +1 -exec rm -f {} \;
find /var/tmp -type f -mtime +1 -exec rm -f {} \;
for user in /home/* /root; do
  cache_dir="$user/.cache"
  if [ -d "$cache_dir" ]; then
    rm -rf "$cache_dir"/* > /dev/null 2>&1
  fi
done

# 清理Docker（如果使用Docker）
if command -v docker &> /dev/null
then
    echo "正在清理Docker镜像、容器和卷..."
    docker system prune -a -f --volumes > /dev/null 2>&1
fi

# 清理孤立包
echo "正在清理孤立包..."
deborphan --guess-all | xargs -r apt-get -y remove --purge > /dev/null 2>&1

# 清理包管理器缓存
echo "正在清理包管理器缓存..."
apt-get autoremove -y > /dev/null 2>&1
apt-get clean > /dev/null 2>&1

end_space=$(df / | tail -n 1 | awk '{print $3}')
cleared_space=$((start_space - end_space))
echo "系统清理完成，清理了 $((cleared_space / 1024))M 空间！"
