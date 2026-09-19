#!/bin/bash
# Git稀疏克隆，只克隆指定目录到本地
function git_sparse_clone() {
  branch="$1" repourl="$2" && shift 2
  git clone --depth=1 -b "$branch" --single-branch --filter=blob:none --sparse "$repourl"
  repodir=$(echo "$repourl" | awk -F '/' '{print $(NF)}')
  cd "$repodir" || exit 1
  # --no-cone 才能同时稀疏检出目录和单文件（如 easytier 的 version.mk）
  git sparse-checkout init --no-cone
  git sparse-checkout set "$@"
  mv -f "$@" ../package/
  cd .. && rm -rf "$repodir"
}

# Add packages
# EasyTier 组网（稀疏克隆，menuconfig 里自选 easytier / easytier-noweb）
git_sparse_clone main https://github.com/fightroad/luci-app-easytier easytier easytier-noweb luci-app-easytier version.mk

# Socat 端口转发 LuCI（Lienol 版，兼容新版 socat，配置用 luci_socat 不冲突）
git_sparse_clone main https://github.com/Lienol/openwrt-package luci-app-socat

# PassWall 科学上网（xiaorouji 源，替换 feeds 自带版本）
rm -rf feeds/packages/net/{xray-core,v2ray-geoip,v2ray-geodata,v2ray-geosite,v2ray-geosite-ir,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,v2ray-plugin,xray-plugin,geoview,shadow-tls}
rm -rf feeds/luci/applications/luci-app-passwall
rm -rf package/openwrt-passwall-packages package/openwrt-passwall
git clone --depth 1 https://github.com/xiaorouji/openwrt-passwall-packages package/openwrt-passwall-packages
git clone --depth 1 https://github.com/xiaorouji/openwrt-package package/openwrt-passwall

# frp：用官方预编译包替换 Imm 源码编译（避免 node/host 编 WebUI 失败）
# 保留 feeds 里 Imm 的 files/（init、uci），LuCI 仍用官方 luci-app-frpc
DIY_DIR="$(cd "$(dirname "$0")" && pwd)"
FRP_SRC_MK="$DIY_DIR/frp/Makefile"
FRP_DST_DIR="feeds/packages/net/frp"
if [ ! -f "$FRP_SRC_MK" ]; then
  echo "ERROR: missing $FRP_SRC_MK" >&2
  exit 1
fi
if [ ! -d "$FRP_DST_DIR" ]; then
  echo "ERROR: missing $FRP_DST_DIR (run feeds install first)" >&2
  exit 1
fi
cp -f "$FRP_SRC_MK" "$FRP_DST_DIR/Makefile"
echo "frp: using official prebuilt binary Makefile ($(grep '^PKG_VERSION:=' "$FRP_DST_DIR/Makefile"))"

# frpc：LuCI 启用开关 + 默认关闭（避免未配置时连 127.0.0.1:7000 反复重启）
chmod +x "$DIY_DIR/frp/patch_enable.sh"
"$DIY_DIR/frp/patch_enable.sh" \
  "feeds/packages/net/frp/files" \
  "feeds/luci/applications/luci-app-frpc/htdocs/luci-static/resources/view/frpc.js"
#git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon package/luci-theme-argon
#git clone --depth 1 https://github.com/jerrykuku/luci-app-argon-config package/luci-app-argon-config
#git clone --depth 1 https://github.com/sirpdboy/luci-app-ddns-go package/ddnsgo
#git clone --depth 1 https://github.com/sbwml/luci-app-mosdns package/mosdns
#git clone --depth 1 https://github.com/sbwml/luci-app-alist package/alist
#git clone --depth=1  https://github.com/kenzok8/small-package package/small-package
#git_sparse_clone main https://github.com/kiddin9/kwrt-packages luci-app-zerotier
#git_sparse_clone main https://github.com/kiddin9/kwrt-packages vlmcsd
#git_sparse_clone main https://github.com/kiddin9/kwrt-packages luci-app-vlmcsd
#git_sparse_clone main https://github.com/kiddin9/kwrt-packages luci-app-socat

# 替换luci-app-openvpn-server imm源的启动不了服务！
#rm -rf feeds/luci/applications/luci-app-openvpn-server
#git_sparse_clone main https://github.com/kiddin9/kwrt-packages luci-app-openvpn-server
# 调整 openvpn-server 到 VPN 菜单
#sed -i 's/services/vpn/g' package/luci-app-openvpn-server/luasrc/controller/*.lua
#sed -i 's/services/vpn/g' package/luci-app-openvpn-server/luasrc/model/cbi/openvpn-server/*.lua
#sed -i 's/services/vpn/g' package/luci-app-openvpn-server/luasrc/view/openvpn/*.htm

#git clone -b js https://github.com/papagaye744/luci-theme-design package/luci-theme-design

#删除库中的插件，使用自定义源中的包。
#rm -rf feeds/luci/themes/luci-theme-argon
#rm -rf feeds/luci/applications/luci-app-argon-config
#rm -rf feeds/luci/applications/luci-app-ddns-go
#rm -rf feeds/packages/net/ddns-go
#rm -rf feeds/packages/net/alist
#rm -rf feeds/luci/applications/luci-app-alist

#修改默认IP
#sed -i 's/192.168.1.1/192.168.123.1/g' package/base-files/files/bin/config_generate

#修改主机名
#sed -i "s/hostname='ImmortalWrt'/hostname='Redmi-AX6'/g" package/base-files/files/bin/config_generate

# ============================================================
# Redmi AX6 1GB RAM - use full ath11k memory profile
# ============================================================

AX6_DTS="target/linux/qualcommax/dts/ipq8071-ax6.dts"
ATH11K_MK="package/kernel/mac80211/ath.mk"

echo "Applying AX6 1GB ath11k memory profile..."

# 1. ath11k firmware:
#    Mode 1 (low-memory) -> Mode 0 (full/default profile)
if grep -q 'qcom,ath11k-fw-memory-mode = <1>;' "$AX6_DTS"; then
    sed -i \
        's/qcom,ath11k-fw-memory-mode = <1>;/qcom,ath11k-fw-memory-mode = <0>;/' \
        "$AX6_DTS"
else
    echo "ERROR: expected ath11k memory mode setting not found in $AX6_DTS"
    exit 1
fi

# 2. ath11k driver:
#    Remove compile-time 512MB memory profile
if grep -q 'ATH11K_MEM_PROFILE_512M' "$ATH11K_MK"; then
    sed -i \
        '/CONFIG_ATH11K_NSS_SUPPORT.*ATH11K_MEM_PROFILE_512M/ s/ ATH11K_MEM_PROFILE_512M//' \
        "$ATH11K_MK"
else
    echo "ERROR: ATH11K_MEM_PROFILE_512M not found in $ATH11K_MK"
    exit 1
fi

# Verify
echo "AX6 DTS memory mode:"
grep 'ath11k-fw-memory-mode' "$AX6_DTS"

echo "ath11k NSS compile profile:"
grep 'CONFIG_ATH11K_NSS_SUPPORT' "$ATH11K_MK"

echo "AX6 1GB ath11k profile applied successfully."


# Fix empty /etc/board.json preventing regeneration during preinit
BOARD_GEN="package/base-files/files/lib/preinit/82_config_generate"

if grep -q '\[ -f /etc/board.json \] || {' "$BOARD_GEN"; then
    sed -i \
        's/\[ -f \/etc\/board.json \] || {/[ -s \/etc\/board.json ] || {/' \
        "$BOARD_GEN"
    echo "board.json preinit check patched: -f -> -s"
else
    echo "ERROR: expected board.json check not found in $BOARD_GEN"
    exit 1
fi

BOOT_FILE="package/base-files/files/etc/init.d/boot"

if grep -q '\[ -f /etc/board.json \] && /sbin/wifi config' "$BOOT_FILE"; then
    sed -i \
        's/\[ -f \/etc\/board.json \] \&\& \/sbin\/wifi config/[ -s \/etc\/board.json ] \&\& \/sbin\/wifi config/' \
        "$BOOT_FILE"
    echo "wifi board.json check patched: -f -> -s"
else
    echo "ERROR: expected wifi board.json check not found in $BOOT_FILE"
    exit 1
fi