#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#

# 取消插件注释
# sed -i 's/^#\(.*helloworld\)/\1/' feeds.conf.default

# 添加插件源码
# sed -i '$a src-git ddnsto https://github.com/linkease/ddnsto-openwrt' feeds.conf.default
# sed -i '$a src-git adguardhome https://github.com/rufengsuixing/luci-app-adguardhome' feeds.conf.default
# sed -i '$a src-git dnsfilter https://github.com/garypang13/luci-app-dnsfilter' feeds.conf.default

# 添加插件源码
# sed -i '$a src-git kenzo https://github.com/kenzok8/openwrt-packages' feeds.conf.default
# passwall依赖
# sed -i '$a src-git small https://github.com/kenzok8/small' feeds.conf.default

### 修改为R4A千兆版Breed直刷版
cp -f "$GITHUB_WORKSPACE/mt7621_xiaomi_mi-router-4a-3g-v2.dtsi" target/linux/ramips/dts
cp -f "$GITHUB_WORKSPACE/mt7621.mk" target/linux/ramips/image