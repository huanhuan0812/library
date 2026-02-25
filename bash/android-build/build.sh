#!/bin/bash

# 版本文件路径
VERSION_FILE=".version"

# 默认值
VERSION_CODE=1
VERSION_NAME="1.0.0"
NEW_VERSION_NAME=""
SCRIPT_VERSION="1.1.0"  # 更新脚本版本
BUILD_TYPE="release"  # 默认构建类型

# 显示帮助
show_help() {
    cat << EOF
用法: $0 [选项]

选项:
    -n, --newversion NAME    设置新的版本名称
    -c, --code NUMBER        手动指定 versionCode
    -s, --skip-increment     跳过 versionCode 自动增加
    -t, --type TYPE          构建类型: debug 或 release (默认: release)
    -v, --version            显示当前版本信息
    -h, --help               显示帮助

说明:
    * versionCode 会自动累加（除非使用 --skip-increment 跳过）
    * 可以使用 --code 手动指定 versionCode
    * 可以使用 --newversion 更新版本名称，versionCode 继续累加
    * 可以使用 --type 选择构建 debug 或 release 版本

示例:
    $0                         # 构建 release 版本，versionCode +1
    $0 --type debug             # 构建 debug 版本，versionCode +1
    $0 --newversion "1.1.0"     # 更新版本名称，versionCode +1
    $0 --type debug --newversion "1.1.0"  # 更新版本名称，构建 debug 版本
    $0 --type debug --code 5     # 构建 debug 版本，手动指定 versionCode=5
    $0 --skip-increment          # 构建 release 版本，versionCode 不变
EOF
    exit 0
}

# 显示版本信息
show_version() {
    if [ -f "$VERSION_FILE" ]; then
        source "$VERSION_FILE"
        echo "项目版本信息:"
        echo "  Version Code: $VERSION_CODE"
        echo "  Version Name: $VERSION_NAME"
    else
        echo "未找到版本文件，使用默认值"
        echo "  Version Code: $VERSION_CODE (默认)"
        echo "  Version Name: $VERSION_NAME (默认)"
    fi
    echo "脚本版本: $SCRIPT_VERSION"
    exit 0
}

# 读取现有版本信息
read_version() {
    if [ -f "$VERSION_FILE" ]; then
        source "$VERSION_FILE"
        echo "当前版本信息:"
        echo "  Version Code: $VERSION_CODE"
        echo "  Version Name: $VERSION_NAME"
    else
        echo "未找到版本文件，使用默认值"
    fi
}

# 保存版本信息
save_version() {
    cat > "$VERSION_FILE" << EOF
VERSION_CODE=$VERSION_CODE
VERSION_NAME="$VERSION_NAME"
EOF
    echo "版本信息已保存到 $VERSION_FILE"
}

# 打开目录的函数
open_directory() {
    local dir_path="$1"
    
    if [ ! -d "$dir_path" ]; then
        echo "目录不存在: $dir_path"
        return 1
    fi
    
    echo "尝试打开目录: $dir_path"
    
    # 根据操作系统选择打开命令
    case "$(uname -s)" in
        Linux)
            if command -v xdg-open > /dev/null; then
                xdg-open "$dir_path"
            elif command -v nautilus > /dev/null; then
                nautilus "$dir_path"
            elif command -v dolphin > /dev/null; then
                dolphin "$dir_path"
            elif command -v thunar > /dev/null; then
                thunar "$dir_path"
            else
                echo "警告: 找不到合适的文件管理器，请手动打开目录"
                return 1
            fi
            ;;
        Darwin)  # macOS
            if command -v open > /dev/null; then
                open "$dir_path"
            else
                echo "警告: 找不到 'open' 命令，请手动打开目录"
                return 1
            fi
            ;;
        CYGWIN*|MINGW*|MSYS*)  # Windows
            if command -v explorer > /dev/null; then
                explorer "$(cygpath -w "$dir_path")"
            else
                echo "警告: 找不到 'explorer' 命令，请手动打开目录"
                return 1
            fi
            ;;
        *)
            echo "警告: 不支持的操作系统，请手动打开目录"
            return 1
            ;;
    esac
    
    echo "✅ 目录已打开"
    return 0
}

# 解析参数
SKIP_INCREMENT=false
MANUAL_CODE=""

while [ $# -gt 0 ]; do
    case "$1" in
        -n|--newversion)
            NEW_VERSION_NAME="$2"
            shift 2
            ;;
        -c|--code)
            MANUAL_CODE="$2"
            shift 2
            ;;
        -s|--skip-increment)
            SKIP_INCREMENT=true
            shift
            ;;
        -t|--type)
            BUILD_TYPE="$2"
            # 验证构建类型
            if [[ ! "$BUILD_TYPE" =~ ^(debug|release)$ ]]; then
                echo "错误: 构建类型必须是 'debug' 或 'release'"
                exit 1
            fi
            shift 2
            ;;
        -v|--version)
            show_version
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "未知选项: $1"
            show_help
            ;;
    esac
done

# 读取当前版本
read_version

# 保存旧的版本信息用于显示
OLD_CODE=$VERSION_CODE
OLD_NAME=$VERSION_NAME

# 处理 versionName
if [ ! -z "$NEW_VERSION_NAME" ]; then
    VERSION_NAME="$NEW_VERSION_NAME"
    echo "更新版本名称: \"$OLD_NAME\" -> \"$VERSION_NAME\""
fi

# 处理 versionCode
if [ ! -z "$MANUAL_CODE" ]; then
    # 手动指定了 versionCode
    if [[ "$MANUAL_CODE" =~ ^[0-9]+$ ]]; then
        VERSION_CODE=$MANUAL_CODE
        echo "使用手动指定的 Version Code: $OLD_CODE -> $VERSION_CODE"
    else
        echo "错误: Version Code 必须是数字"
        exit 1
    fi
elif [ "$SKIP_INCREMENT" = false ]; then
    # 自动增加 versionCode（无论是否更改版本名称，都累加）
    VERSION_CODE=$((VERSION_CODE + 1))
    echo "Version Code 自动增加: $OLD_CODE -> $VERSION_CODE"
else
    echo "Version Code 保持不变: $VERSION_CODE"
fi

# 根据构建类型确定 Gradle task
case "$BUILD_TYPE" in
    debug)
        GRADLE_TASK="assembleDebug"
        APK_SUFFIX="debug"
        ;;
    release)
        GRADLE_TASK="assembleRelease"
        APK_SUFFIX="release"
        ;;
esac

# 显示版本变化和构建信息
echo ""
echo "版本变更:"
echo "  Version Code: $OLD_CODE -> $VERSION_CODE"
echo "  Version Name: \"$OLD_NAME\" -> \"$VERSION_NAME\""
echo "构建信息:"
echo "  构建类型: $BUILD_TYPE"
echo "  Gradle Task: $GRADLE_TASK"
echo ""

# 确认构建
read -p "是否继续构建 $BUILD_TYPE 版本？(y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "构建取消"
    exit 1
fi

# 执行构建
echo "开始构建 $BUILD_TYPE 版本..."
echo "执行: ./gradlew $GRADLE_TASK -PversionCode=$VERSION_CODE -PversionName=\"$VERSION_NAME\""
echo ""

if ./gradlew $GRADLE_TASK -PversionCode=$VERSION_CODE -PversionName="$VERSION_NAME"; then
    # 构建成功，保存版本信息
    save_version
    
    # 查找生成的 APK 文件
    echo ""
    echo "构建成功！"
    echo "查找生成的 APK 文件..."
    
    # 常见的 APK 输出路径
    APK_PATHS=(
        "app/build/outputs/apk/$BUILD_TYPE/app-$BUILD_TYPE.apk"
        "app/build/outputs/apk/$BUILD_TYPE/app-${BUILD_TYPE}.apk"
        "app/build/outputs/apk/${BUILD_TYPE}/app-${VERSION_NAME}-${VERSION_CODE}-${BUILD_TYPE}.apk"
        "app/build/outputs/apk/${BUILD_TYPE}/app-${BUILD_TYPE}-${VERSION_CODE}.apk"
    )
    
    FOUND_APK=false
    APK_DIR=""
    for apk_path in "${APK_PATHS[@]}"; do
        if [ -f "$apk_path" ]; then
            echo "  ✅ APK 生成位置: $apk_path"
            echo "  📦 文件大小: $(du -h "$apk_path" | cut -f1)"
            FOUND_APK=true
            APK_DIR=$(dirname "$apk_path")
        fi
    done
    
    if [ "$FOUND_APK" = false ]; then
        # 尝试查找任何 APK 文件
        SEARCH_DIR="app/build/outputs/apk/$BUILD_TYPE"
        if [ -d "$SEARCH_DIR" ]; then
            APK_FILES=$(find "$SEARCH_DIR" -name "*.apk" -type f 2>/dev/null | head -5)
            if [ ! -z "$APK_FILES" ]; then
                echo "  在以下位置找到 APK 文件:"
                while IFS= read -r apk_file; do
                    echo "    ✅ $apk_file ($(du -h "$apk_file" | cut -f1))"
                done <<< "$APK_FILES"
                FOUND_APK=true
                APK_DIR="$SEARCH_DIR"
            fi
        fi
    fi
    
    if [ "$FOUND_APK" = false ]; then
        echo "  ⚠️ 未找到 APK 文件"
        # 使用标准输出目录
        APK_DIR="app/build/outputs/apk/$BUILD_TYPE"
    fi
    
    echo ""
    echo "✨ 构建完成！"
    echo ""
    
    # 询问是否打开构建目录
    if [ -d "$APK_DIR" ]; then
        echo "构建目录: $APK_DIR"
        read -p "是否打开构建目录？(y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            open_directory "$APK_DIR"
        fi
    else
        echo "构建目录不存在: $APK_DIR"
        # 尝试打开上级目录
        PARENT_DIR="app/build/outputs/apk"
        if [ -d "$PARENT_DIR" ]; then
            read -p "是否打开 APK 输出目录？(y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                open_directory "$PARENT_DIR"
            fi
        fi
    fi
else
    echo "构建失败！"
    exit 1
fi