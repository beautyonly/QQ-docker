#!/bin/bash
#
# wget http://t.cn/RWiJZda -O- | /usr/bin/time -v bash
#
# 设置用户名 && 与登录密码
# 登录用户
user_name="beautyonly"
# gmail填写此处
user_email="beautytao@protonmail.com"

export DEBIAN_FRONTEND=noninteractive

# Utils

# get distro version
distro_version=$(lsb_release -s -c)

# Update
function update_apt() {
	sudo apt-get update
	sudo apt-get dist-upgrade -y
}

function config_apt() {
	cat <<EOF | sudo tee /etc/apt/apt.conf.d/50no-recommends
APT::Get::Install-Recommends "false";
APT::Get::Install-Suggests "false";
EOF
}

# Common Tools
function install_common() {
	sudo apt-get install -y \
		apt-transport-https \
		curl \
		zsh \
		zsh-antigen \
		zsh-syntax-highlighting \
		pv \
		git \
		jq \
		tree \
		tzdata \
		strace \
		build-essential \
		lsb-release \
		gddrescue \
		terminator

	case "$distro_version" in
		xenial)
			# gnupg 1 cannot fetch key from HTTPS, so we need gnupg-curl
			sudo apt-get install -y gnupg-curl
			;;
		artful)
			# It's good to have neofetch for fun, but it's only available since 17.04
			sudo apt-get install -y neofetch
			;;
	esac
}

# Graphics Driver 图形驱动程序
function install_graphics() {
	case "$1" in
		intel)	sudo apt-get install -y xserver-xorg-video-intel	;;
	esac
}

# Kernel 核心
function install_kernel() {
	case "$distro_version" in
		xenial)
			# Let's use HWE kernel, so we will have 4.10 on Ubuntu 16.04
			sudo apt-get install -y \
				linux-generic-hwe-16.04 \
				xserver-xorg-hwe-16.04
				;;
	esac
}

# Git 登录git
function install_git() {
	local user_name=$1
	local user_email=$2
	git config --global credential.helper store
	git config --global user.name $user_name
	git config --global user.email $user_email
}

# Docker 安装Docker
function install_docker() {
	if dpkg -l | grep docker | grep -q ii; then
		echo "Docker has been installed already."
		return
	fi

	sudo addgroup --system docker
	sudo adduser $USER docker
	newgrp docker

	# curl -fsSL https://get.docker.com/ | sh -s -- --mirror Aliyun
	curl -fsSL https://get.docker.com/ | sh
}

# Virtualbox 虚拟机
function install_virtualbox() {
	case "$distro_version" in
		artful)
			# Ubuntu 17.10 is not supported by Virtualbox Official repo yet.
			# Accept Virtualbox PUEL
			echo virtualbox-ext-pack virtualbox-ext-pack/license select true | sudo debconf-set-selections
			# Install virtualbox from Ubuntu source
			sudo apt-get install -y \
				virtualbox \
				virtualbox-dkms \
				virtualbox-ext-pack \
				virtualbox-guest-additions-iso
			;;
		*)
			echo "deb http://download.virtualbox.org/virtualbox/debian $distro_version contrib" \
				| sudo tee /etc/apt/sources.list.d/virtualbox.list
			wget -q -O- http://download.virtualbox.org/virtualbox/debian/oracle_vbox_2016.asc | sudo apt-key add
			sudo apt-get update
			sudo apt-get install -y virtualbox-5.2
			;;
	esac
}

# Adapta - Material Design theme && Adapta - 材料设计主题
function install_adapta() {
	# Adapta - Material Design 材料设计
	sudo add-apt-repository -y ppa:tista/adapta
	sudo apt-get update
	sudo apt-get install -y adapta-gtk-theme

	# Setting the theme && 设置主题
	gsettings set org.gnome.desktop.interface gtk-theme "Adapta-Nokto"
	gsettings set org.gnome.desktop.interface cursor-theme "DMZ-Black"

	# Paper Icon && 纸图标
	sudo add-apt-repository -y ppa:snwh/pulp
	sudo apt-get update
	sudo apt-get install -y \
		paper-icon-theme \
		paper-cursor-theme
	gsettings set org.gnome.desktop.interface cursor-theme "Paper"
	gsettings set org.gnome.desktop.interface icon-theme "Paper"

	# GNOME Tweak Tools && GNOME调整工具
	sudo apt-get install -y gnome-tweak-tool
}

# 中文输入法
## 安装 fcitx
function install_fcitx() {
	# Wayland is not supported by fcitx yet, so don't use it on 17.10+
	if dpkg -l fcitx | grep -q ii; then
		echo "FCITX has been installed already."
		return
	fi

	sudo apt-get install -y \
		fcitx \
		fcitx-config-gtk \
		fcitx-table-all \
		fcitx-googlepinyin \
		fcitx-module-cloudpinyin \
		fcitx-pinyin \
		im-config
	im-config -n fcitx

	if grep -q XMODIFIERS /etc/environment; then
		echo "IM environment variables have been added already."
		return
	fi

	cat <<EOF | sudo tee -a /etc/environment
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
EOF

	# 这里我们只需要 fcitx，所以删除所有 ibus 的包
	sudo apt-get purge -y "ibus*"
}

## 安装搜狗输入法
function install_sogou() {
	install_fcitx

	if dpkg -l sogoupinyin | grep -q ii; then
		echo "Sogou Pinyin has been installed already."
		return
	fi

	wget "https://pinyin.sogou.com/linux/download.php?f=linux&bit=64" -O /tmp/sogoupinyin.deb
	sudo apt install -y /tmp/sogoupinyin.deb
	rm /tmp/sogoupinyin.deb
}

## 安装 iBus 输入法
function install_ibus() {
	# 安装 Pinyin 输入法
	sudo apt-get install -y ibus-pinyin
	# 指定 pinyin 输入法
	gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('ibus', 'pinyin')]"
	# 删除 sun pinyin
	sudo apt-get purge -y ibus-sunpinyin
	# 我们只需要 ibus，所以删除所有 fcitx 相关的包。
	sudo apt-get purge -y "fcitx*"
}

# Dropbox && 在线存储服务 多宝箱
function install_dropbox() {
	sudo apt-key adv --keyserver pgp.mit.edu --recv-keys 5044912E
	echo "deb http://linux.dropbox.com/ubuntu/ xenial main" | sudo tee /etc/apt/sources.list.d/dropbox.list
	sudo apt-get update
	sudo apt-get install -y dropbox python-gpgme
}

# Wire 加密沟通软件
function install_wire() {
	echo "deb https://wire-app.wire.com/linux/debian stable main" | sudo tee /etc/apt/sources.list.d/wire-desktop.list
	wget -q -O- https://wire-app.wire.com/linux/releases.key | sudo apt-key add
	sudo apt-get update
	sudo apt-get install -y wire-desktop
}
# keeweb 密码存储 https://keeweb.info/
function install_keeweb() {
	KEEWEB_VERSION=1.5.6
	if dpkg -l keeweb-desktop | grep -q ii; then
		echo "KeeWeb has been installed already."
		return
	fi

	wget https://github.com/keeweb/keeweb/releases/download/v$KEEWEB_VERSION/KeeWeb-$KEEWEB_VERSION.linux.x64.deb -O /tmp/keeweb.deb
	sudo apt install -y /tmp/keeweb.deb
	rm /tmp/keeweb.deb
}

# Chrome 谷歌浏览器
function install_chrome() {
	echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
	wget -q -O- https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add
	sudo apt-get update
	sudo apt-get install -y google-chrome-stable
}

# Zeal
function install_zeal() {
	if dpkg -l zeal | grep -q ii; then
		echo "Zeal has been installed already."
		return
	fi

	sudo add-apt-repository ppa:zeal-developers/ppa
	sudo apt-get update
	sudo apt-get install -y zeal
}

# Visual Studio Code 
function install_vscode() {
	if dpkg -l code | grep -q ii; then
		echo "VSCode has been installed already."
		return
	fi

	# Prepare apt source && 准备源码
	echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
	wget -q -O- https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add

	# Install 安装
	sudo apt-get update
	sudo apt-get install -y code

	# Extensions 扩展
	case $1 in
		with_extensions)
			code --install-extension ms-vscode.cpptools
			code --install-extension formulahendry.code-runner
			code --install-extension anseki.vscode-color
			code --install-extension PeterJausovec.vscode-docker
			code --install-extension Perkovec.emoji
			code --install-extension dbaeumer.vscode-eslint
			code --install-extension donjayamanne.githistory
			code --install-extension eamodio.gitlens
			code --install-extension lukehoban.go
			code --install-extension abusaidm.html-snippets
			code --install-extension shd101wyy.markdown-preview-enhanced
			code --install-extension mdickin.markdown-shortcuts
			code --install-extension DavidAnson.vscode-markdownlint
			# code --install-extension robertohuertasm.vscode-icons
			code --install-extension PKief.material-icon-theme
			code --install-extension Ikuyadeu.r
			code --install-extension itryapitsin.scala
			code --install-extension marcostazi.vs-code-vagrantfile
			# code --install-extension WakaTime.vscode-wakatime
			code --install-extension dzannotti.vscode-babel-coloring
			code --install-extension HookyQR.beautify
			code --install-extension msjsdiag.debugger-for-chrome
			code --install-extension ms-vscode.atom-keybindings
			;;
	esac
}

# Snap apps && 捕捉应用程序
function install_snaps() {
	sudo snap install --classic go
}

# Remove Unwanted && 删除不需要的
function remove_unwanted() {
	# Remove apport and games 删除apport和游戏
	sudo apt-get purge -y apport

	# Games 游戏
	sudo apt-get purge -y gnome-sudoku
	sudo apt-get purge -y gnome-mahjongg
	sudo apt-get purge -y gnome-mines
	sudo apt-get purge -y aisleriot

	# Firefox 火狐浏览器
	sudo apt-get purge -y firefox

	# Transmission 传输
	sudo apt-get purge -y transmission-gtk

	case "$distro_version" in
		xenial)
			# Amazon adware 亚马逊广告软件
			sudo apt-get purge -y unity-webapps-common
			# Other not used apps
			sudo apt-get purge -y empathy
			sudo apt-get purge -y evolution
			sudo apt-get purge -y brasero
			;;
		artful)
			# Amazon adware 亚马逊广告软件
			sudo apt-get purge -y ubuntu-web-launchers
			;;
	esac

	# autoremove
	sudo apt-get autoremove -y
}

# oh-my-zsh 管理您的zsh配置的框架
# 官方网址 http://ohmyz.sh/
function install_oh_my_zsh() {
	bash -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

	# Setup ZSH 设置ZSH
	local ZSH_CUSTOM=${ZSH_CUSTOM:-~/.oh-my-zsh/custom}

	mkdir -p $ZSH_CUSTOM/themes
	mkdir -p $ZSH_CUSTOM/plugins

	## Theme 主题
	if [ ! -f $ZSH_CUSTOM/zeta_theme.zsh ]; then
		wget https://raw.githubusercontent.com/skylerlee/zeta-zsh-theme/master/zeta.zsh-theme -O $ZSH_CUSTOM/themes/zeta.zsh-theme
		echo 'ZSH_THEME="zeta"' > $ZSH_CUSTOM/zeta_theme.zsh
	fi

	## Alias 别号
	if [ ! -f $ZSH_CUSTOM/alias.zsh ]; then
		cat <<EOF | tee $ZSH_CUSTOM/alias.zsh
# My Alias

alias ll='ls -al'
alias brewup='brew update && brew upgrade && brew cleanup; brew doctor; brew cask outdated'
alias dsh='docker run -it --rm --privileged --pid=host debian nsenter -t 1 -m -u -n -i sh'
alias docker_stats='docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}\t{{.PIDs}}"'

EOF
	fi

	## Functions 功能
	if [ ! -f $ZSH_CUSTOM/func.zsh ]; then
		cat <<EOF | tee $ZSH_CUSTOM/func.zsh
# My Functions

function show_certs() {
  local server=$1
  if [ -z "$1" ]; then
    echo "Usage: show_certs www.example.com"
    return 1
  fi
  
  local port=${2:-443}
  echo \
    | openssl s_client \
      -showcerts \
      -servername "$server" \
      -connect "$server:$port" \
      2>/dev/null \
    | openssl x509 -inform pem -noout -text
}

# 寻找最新的40个文件。
function find_latest() {
  if [ -z "$1" ]; then
    echo "Usage: find_latest <directory> [number]
    return 1
  fi

  local num=${2:-10}

  find $1 -type f -printf '%T@ %p\n' | sort -n | tail -$num | cut -f2- -d" "
}

EOF
	fi


	## locales 语言环境
	if [ ! -f $ZSH_CUSTOM/locales.zsh ]; then
		echo <<EOF | tee $ZSH_CUSTOM/locales.zsh
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
EOF
	fi

	## golang
	if [ ! -f $ZSH_CUSTOM/golang.zsh ]; then
		mkdir -p ~/lab/go
		echo <<EOF | tee $ZSH_CUSTOM/golang.zsh
export GOPATH=$HOME/lab/go
export GOBIN=$GOPATH/bin
export PATH=$PATH:$GOBIN
EOF
	fi

	## path 路径
	if [ ! -f $ZSH_CUSTOM/path.zsh ]; then
		mkdir -p ~/bin
		echo "export PATH=$PATH:$HOME/bin:$HOME/Dropbox/bin" | tee $ZSH_CUSTOM/path.zsh
	fi

	## zsh-antigen
	if [ ! -f $ZSH_CUSTOM/antigen.zsh ]; then
		cat <<EOF | tee $ZSH_CUSTOM/antigen.zsh
source /usr/share/zsh-antigen/antigen.zsh

antigen bundle git
antigen bundle golang
antigen bundle heroku
antigen bundle command-not-found
antigen bundle gpg-agent
antigen bundle docker
antigen bundle docker-compose

if [ "$(uname)" = "Darwin" ]; then
	antigen bundle brew
	antigen bundle osx
fi

# if [ "$(lsb_release -si)" = "Ubuntu" ]; then
# 	antigen bundle ubuntu
# fi

antigen bundle wbinglee/zsh-wakatime
antigen bundle zsh-users/zsh-autosuggestions

antigen apply

EOF
	fi

	## zsh-syntax-highlighting zsh的语法，高亮
	if ! grep -q "zsh-syntax-highlighting.zsh"; then
		# this should be the last line of `.zshrc`
		echo "source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" | tee -a ~/.zshrc
	fi

	echo "Please run: chsh -s $(which zsh)"
}

function install_bin() {
	BASEURL=https://github.com/beautyonly/QQ-docker/blob/master
	mkdir -p ~/bin
	wget $BASEURL/bin/qq -O ~/bin/qq
	wget $BASEURL/bin/ss -O ~/bin/ss

	chmod u+x ~/bin/*
}

# Add favorite apps to the dock 增加最喜欢的应用程序到码头
function add_favorite_apps() {
	local current=$(gsettings get org.gnome.shell favorite-apps)
	if [[ $current == *"terminator"* ]]; then
		echo "Already added my favorite apps"
	else
		# Append following apps to the favorite apps
		local favs=( \
			google-chrome.desktop \
			code.desktop \
			terminator.desktop \
			yelp.desktop \
			keeweb.desktop \
			zeal.desktop \
			wire-desktop.desktop \
		)
		# We don't preserve the default apps but Nautilus
		local value=$(echo "['org.gnome.Nautilus.desktop'" $(printf ", '%s'" "${favs[@]}") "]")
		gsettings set org.gnome.shell favorite-apps "$value"
	fi
	# print the favoite apps for sure
	gsettings get org.gnome.shell favorite-apps
}

function prepare_lab() {
	mkdir -p ~/lab/go
}

function main() {
	update_apt
	config_apt
	install_common
	# install_graphics intel
	install_kernel
	install_git
	install_docker
	install_virtualbox
	install_adapta

	# 输入法选择
	case "$distro_version" in
		xenial)
			install_sogou
			;;
		artful)
			# fcitx 尚不支持 Wayland，所以只可以用 ibus
			install_ibus
			;;
	esac
	install_dropbox
	install_wire
	install_keeweb
	install_chrome
	install_vscode with_extensions
	install_zeal
	install_snaps
	remove_unwanted
	install_bin
	add_favorite_apps
	prepare_lab
	install_oh_my_zsh
}

main
