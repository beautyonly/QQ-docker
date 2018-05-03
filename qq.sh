#!/bin/bash
# qq.sh
#
# 地址： https://github.com/beautyonly/QQ-docker.git
#
# 运行 qq： ./qq.sh start
# 结束 qq： ./qq.sh stop
#
# * 运行 docker 命令如果碰到权限不够，请不要使用 sudo，这是因为当前用户不在 docker 组，执行下面命令：
#
# 	sudo addgroup --system docker
#	sudo adduser $USER docker
#	newgrp docker
#


# 设置所使用的输入法
# IM=fcitx
# IM=ibus
IM=${GTK_IM_MODULE:-ibus}

function stop() {
    if [ -n "$(docker ps -a -f "name=qq" -q)" ]; then
        # Ask qq to stop first
        docker stop qq
        # Then kill it later.
        docker rm -f qq
    fi
}

function start() {
    stop

    docker run -d --name qq \
        --device /dev/snd \
        -v /tmp/.X11-unix:/tmp/.X11-unix \
        -v $HOME/TencentFiles:/TencentFiles \
        -e DISPLAY=unix$DISPLAY \
        -e XMODIFIERS=@im=$IM \
        -e QT_IM_MODULE=$IM \
        -e GTK_IM_MODULE=$IM \
        -e AUDIO_GID=`getent group audio | cut -d: -f3` \
        -e VIDEO_GID=`getent group video | cut -d: -f3` \
        -e GID=$GID \
        -e UID=$UID \
        bestwu/qq:office
}

command=$1
shift
case $command in
    start)      start ;;
    stop)       stop ;;
    restart)    docker restart qq ;;
    *)      echo "Usage: $0 (start|stop)" ;;
esac
