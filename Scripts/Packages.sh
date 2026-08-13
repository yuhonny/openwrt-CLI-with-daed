#!/bin/bash

# 安装和更新软件包
UPDATE_PACKAGE() {
    local PKG_NAME=$1
    local PKG_REPO=$2
    local PKG_BRANCH=$3
    local PKG_SPECIAL=$4
    local PKG_LIST=("$PKG_NAME" $5)  # 第5个参数为自定义名称列表
    local REPO_NAME=${PKG_REPO#*/}

    echo " "

    # 删除本地可能存在的不同名称的软件包
    for NAME in "${PKG_LIST[@]}"; do
        # 查找匹配的目录
        echo "Search directory: $NAME"
        local FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)

        # 删除找到的目录
        if [ -n "$FOUND_DIRS" ]; then
            while read -r DIR; do
                rm -rf "$DIR"
                echo "Delete directory: $DIR"
            done <<< "$FOUND_DIRS"
        else
            echo "Not fonud directory: $NAME"
        fi
    done

    # 克隆 GitHub 仓库
    git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git"

    # 处理克隆的仓库
    if [[ "$PKG_SPECIAL" == "pkg" ]]; then
        find ./$REPO_NAME/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./ \;
        rm -rf ./$REPO_NAME/
    elif [[ "$PKG_SPECIAL" == "name" ]]; then
        mv -f $REPO_NAME $PKG_NAME
    fi
}

# UPDATE_PACKAGE "包名" "项目地址" "项目分支" "pkg/name，可选，pkg为从大杂烩中单独提取包名插件；name为重命名为包名"
UPDATE_PACKAGE "argon" "sbwml/luci-theme-argon" "openwrt-25.12"
UPDATE_PACKAGE "aurora" "eamonxg/luci-theme-aurora" "master"
UPDATE_PACKAGE "aurora-config" "eamonxg/luci-app-aurora-config" "master"
UPDATE_PACKAGE "kucat" "sirpdboy/luci-theme-kucat" "master"
UPDATE_PACKAGE "kucat-config" "sirpdboy/luci-app-kucat-config" "master"

UPDATE_PACKAGE "homeproxy" "VIKINGYFY/homeproxy" "main"
UPDATE_PACKAGE "momo" "nikkinikki-org/OpenWrt-momo" "main"
UPDATE_PACKAGE "nikki" "nikkinikki-org/OpenWrt-nikki" "main"
UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "dev" "pkg"
UPDATE_PACKAGE "passwall" "Openwrt-Passwall/openwrt-passwall" "main" "pkg"
UPDATE_PACKAGE "passwall2" "Openwrt-Passwall/openwrt-passwall2" "main" "pkg"

UPDATE_PACKAGE "luci-app-tailscale" "asvow/luci-app-tailscale" "main"

UPDATE_PACKAGE "ddns-go" "sirpdboy/luci-app-ddns-go" "main"
UPDATE_PACKAGE "diskman" "lisaac/luci-app-diskman" "master"
UPDATE_PACKAGE "easytier" "EasyTier/luci-app-easytier" "main"
UPDATE_PACKAGE "fancontrol" "rockjake/luci-app-fancontrol" "main"
UPDATE_PACKAGE "gecoosac" "openwrt-fork/openwrt-gecoosac" "main"
UPDATE_PACKAGE "mosdns" "sbwml/luci-app-mosdns" "v5" "" "v2dat"
UPDATE_PACKAGE "openlist2" "sbwml/luci-app-openlist2" "main"
UPDATE_PACKAGE "partexp" "sirpdboy/luci-app-partexp" "main"
UPDATE_PACKAGE "qbittorrent" "sbwml/luci-app-qbittorrent" "master" "" "qt6base qt6tools rblibtorrent"
UPDATE_PACKAGE "qmodem" "FUjr/QModem" "main"
UPDATE_PACKAGE "quickfile" "sbwml/luci-app-quickfile" "main"
UPDATE_PACKAGE "viking" "VIKINGYFY/packages" "main" "" "luci-app-timewol luci-app-wolplus"
UPDATE_PACKAGE "vnt" "lmq8267/luci-app-vnt" "main"

UPDATE_PACKAGE "luci-app-daed" "QiuSimons/luci-app-daed" "master"
UPDATE_PACKAGE "luci-app-pushbot" "zzsj0928/luci-app-pushbot" "master"
UPDATE_PACKAGE "luci-app-lucky" "sirpdboy/luci-app-lucky" "main"

# 更新软件包版本函数
UPDATE_VERSION() {
    local PKG_NAME=$1
    local PKG_MARK=${2:-false}
    local PKG_FILES=$(find ./ ../feeds/packages/ -maxdepth 3 -type f -wholename "*/$PKG_NAME/Makefile")

    if [ -z "$PKG_FILES" ]; then
        echo "$PKG_NAME not found!"
        return
    fi

    echo -e "\n$PKG_NAME version update has started!"

    for PKG_FILE in $PKG_FILES; do
        local PKG_REPO=$(grep -Po "PKG_SOURCE_URL:=https://.*github.com/\K[^/]+/[^/]+(?=.*)" $PKG_FILE)
        local PKG_TAG=$(curl -sL "https://api.github.com/repos/$PKG_REPO/releases" | jq -r "map(select(.prerelease == $PKG_MARK)) | first | .tag_name")

        local OLD_VER=$(grep -Po "PKG_VERSION:=\K.*" "$PKG_FILE")
        local OLD_URL=$(grep -Po "PKG_SOURCE_URL:=\K.*" "$PKG_FILE")
        local OLD_FILE=$(grep -Po "PKG_SOURCE:=\K.*" "$PKG_FILE")
        local OLD_HASH=$(grep -Po "PKG_HASH:=\K.*" "$PKG_FILE")

        local PKG_URL=$([[ "$OLD_URL" == *"releases"* ]] && echo "${OLD_URL%/}/$OLD_FILE" || echo "${OLD_URL%/}")

        local NEW_VER=$(echo $PKG_TAG | sed -E 's/[^0-9]+/\./g; s/^\.|\.$//g')
        local NEW_URL=$(echo $PKG_URL | sed "s/\$(PKG_VERSION)/$NEW_VER/g; s/\$(PKG_NAME)/$PKG_NAME/g")
        local NEW_HASH=$(curl -sL "$NEW_URL" | sha256sum | cut -d ' ' -f 1)

        echo "old version: $OLD_VER $OLD_HASH"
        echo "new version: $NEW_VER $NEW_HASH"

        if [[ "$NEW_VER" =~ ^[0-9].* ]] && dpkg --compare-versions "$OLD_VER" lt "$NEW_VER"; then
            sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$NEW_VER/g" "$PKG_FILE"
            sed -i "s/PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/g" "$PKG_FILE"
            echo "$PKG_FILE version has been updated!"
        else
            echo "$PKG_FILE version is already the latest!"
        fi
    done
}

# 1. 删除官方 feed 中冲突的默认插件
rm -rf ../feeds/luci/applications/luci-app-{passwall*,mosdns,dockerman,dae*,bypass*}
rm -rf ../feeds/packages/net/{v2ray-geodata,dae*}

# 2. 拷贝本地仓库的自定义 package 覆盖进来
cp -r $GITHUB_WORKSPACE/package/* ./

# 3. 修复 daed Makefile（如果 patches 路径下有自定义文件）
if [ -f "$GITHUB_WORKSPACE/patches/daed/Makefile" ]; then
    rm -rf luci-app-daed/daed/Makefile
    mkdir -p luci-app-daed/daed/
    cp -f $GITHUB_WORKSPACE/patches/daed/Makefile luci-app-daed/daed/
    echo "==== Updated daed Makefile ===="
    cat luci-app-daed/daed/Makefile
fi

# ==================== 动态修复 daed 缺失 web 前端资源问题 ====================
DAED_DIR=$(find ./ -maxdepth 4 -type d -name "daed" | head -n 1)

if [ -n "$DAED_DIR" ]; then
    echo -e "\n[daed] 找到 daed 源码路径: $DAED_DIR"
    
    # 兼容新版 Go 工作区 (wing) 和常规层级
    if [ -d "$DAED_DIR/wing" ]; then
        TARGET_WEB_DIR="$DAED_DIR/wing/web"
    else
        TARGET_WEB_DIR="$DAED_DIR/web"
    fi

    mkdir -p "$TARGET_WEB_DIR"

    # 如果 index.html 不存在，自动从官方 gh-pages 部署分支下载静态网页产物
    if [ ! -f "$TARGET_WEB_DIR/index.html" ]; then
        echo "[daed] 正在下载并解压官方预编译 UI 静态资源 (daed-web)..."
        curl -sL https://github.com/daeuniverse/daed-web/archive/refs/heads/gh-pages.tar.gz | tar -xz -C "$TARGET_WEB_DIR" --strip-components=1 || true
        
        if [ -f "$TARGET_WEB_DIR/index.html" ]; then
            echo "[daed] 前端静态资源下载成功！"
        else
            echo "[daed] 警告：前端资源下载失败，请检查连接！"
        fi
    else
        echo "[daed] 检测到 web 目录已有 index.html，跳过下载。"
    fi
fi
# =========================================================================
