#!/bin/bash

# Rust UEFI 构建脚本
# 支持架构: x86_64, aarch64, i686

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 默认配置
TARGETS=""
BUILD_MODE="release"
CLEAN_BUILD=false
RUN_TESTS=false
VERBOSE=false
BUILD_ALL=false
COPY_EFI=false          # 是否启用复制
COPY_AUTO=false         # 是否自动复制（指定 --copy 时为 true）
COPY_DIR=""             # 复制目标目录（如果指定）

# 显示帮助信息
show_help() {
    echo "Rust UEFI 构建脚本"
    echo ""
    echo "用法: $0 [选项] [架构...]"
    echo ""
    echo "架构:"
    echo "  x86_64, aarch64, i686    指定要构建的架构"
    echo "  all                      构建所有支持的架构"
    echo ""
    echo "选项:"
    echo "  -h, --help               显示此帮助信息"
    echo "  -d, --debug              使用调试模式构建（默认: release）"
    echo "  -c, --clean              构建前清理项目"
    echo "  -t, --test               运行测试（如果可用）"
    echo "  -v, --verbose            显示详细输出"
    echo "  -r, --release            使用发布模式构建（默认）"
    echo "  -cp, --copy [目录]       构建后自动复制 EFI 文件"
    echo "                           如果不指定目录，将复制到 ./<build_mode>/<arch>/"
    echo "                           如果不使用此选项，构建后会询问是否复制"
    echo ""
    echo "示例:"
    echo "  $0 x86_64                                构建"
    echo "  $0 x86_64 --copy                         构建并自动复制到默认目录"
    echo "  $0 x86_64 aarch64 --copy ./efi_files     构建并自动复制到指定目录"
    echo "  $0 all --release --copy                  构建所有并自动复制"
    echo "  $0 i686 --debug --clean                  清理并调试构建"
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -d|--debug)
                BUILD_MODE="debug"
                shift
                ;;
            -r|--release)
                BUILD_MODE="release"
                shift
                ;;
            -c|--clean)
                CLEAN_BUILD=true
                shift
                ;;
            -t|--test)
                RUN_TESTS=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -cp|--copy)
                COPY_EFI=true
                COPY_AUTO=true
                # 检查下一个参数是否为目录（不以 - 开头）
                if [[ $# -gt 1 ]] && [[ ! "$2" =~ ^- ]]; then
                    COPY_DIR="$2"
                    shift 2
                else
                    shift
                fi
                ;;
            all)
                BUILD_ALL=true
                shift
                ;;
            x86_64|aarch64|i686)
                TARGETS="$TARGETS $1"
                shift
                ;;
            *)
                echo -e "${RED}错误: 未知参数 '$1'${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 如果没有指定架构且未设置 BUILD_ALL，则显示帮助
    if [[ -z "$TARGETS" ]] && [[ "$BUILD_ALL" == false ]]; then
        echo -e "${YELLOW}警告: 未指定目标架构${NC}"
        show_help
        exit 1
    fi
    
    # 如果设置了 BUILD_ALL，添加所有架构
    if [[ "$BUILD_ALL" == true ]]; then
        TARGETS="x86_64 aarch64 i686"
    fi
}

# 检查架构支持
check_target_support() {
    local arch=$1
    case $arch in
        x86_64)
            echo "x86_64-unknown-uefi"
            ;;
        aarch64)
            echo "aarch64-unknown-uefi"
            ;;
        i686)
            echo "i686-unknown-uefi"
            ;;
        *)
            echo ""
            return 1
            ;;
    esac
}

# 安装目标工具链
install_target() {
    local rust_target=$1
    
    if ! rustup target list | grep -q "$rust_target (installed)"; then
        echo -e "${BLUE}安装目标: $rust_target${NC}"
        rustup target add "$rust_target"
    else
        echo -e "${GREEN}目标已安装: $rust_target${NC}"
    fi
}

# 清理构建
clean_build() {
    echo -e "${BLUE}清理构建产物...${NC}"
    cargo clean
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}清理完成${NC}"
    else
        echo -e "${RED}清理失败${NC}"
        exit 1
    fi
}

# 询问是否复制 EFI 文件（仅当未使用 --copy 时）
ask_copy_efi() {
    local arch=$1
    local source_file=$2
    local default_dir=$3
    
    echo ""
    echo -e "${CYAN}是否将 $arch 的 EFI 文件复制到 $default_dir？${NC}"
    echo -e "源文件: ${YELLOW}$source_file${NC}"
    read -p "是否复制？(y/N): " -r answer
    
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        return 0  # 是
    else
        return 1  # 否（默认）
    fi
}

# 复制 EFI 文件
copy_efi_file() {
    local arch=$1
    local source_efi=$2
    local dest_dir=$3
    
    # 确保源文件存在
    if [[ ! -f "$source_efi" ]]; then
        echo -e "${RED}错误: 源 EFI 文件不存在: $source_efi${NC}"
        return 1
    fi
    
    # 创建目标目录
    mkdir -p "$dest_dir"
    
    # 获取文件名
    local filename=$(basename "$source_efi")
    local dest_path="$dest_dir/$filename"
    
    # 复制文件
    if cp "$source_efi" "$dest_path"; then
        echo -e "${GREEN}✓ 已复制: $source_efi -> $dest_path${NC}"
        
        # 显示文件大小
        local file_size=$(ls -lh "$dest_path" | awk '{print $5}')
        echo -e "${CYAN}文件大小: $file_size${NC}"
        
        return 0
    else
        echo -e "${RED}✗ 复制失败: $source_efi -> $dest_path${NC}"
        return 1
    fi
}

# 查找并获取 EFI 文件路径
find_efi_file() {
    local arch=$1
    local rust_target=$(check_target_support "$arch")
    local target_dir="target/$rust_target"
    
    if [[ "$BUILD_MODE" == "release" ]]; then
        target_dir="$target_dir/release"
    else
        target_dir="$target_dir/debug"
    fi
    
    # 查找 .efi 文件
    local efi_file=$(find "$target_dir" -maxdepth 1 -name "*.efi" -type f | head -n 1)
    
    if [[ -n "$efi_file" && -f "$efi_file" ]]; then
        echo "$efi_file"
        return 0
    else
        return 1
    fi
}

# 获取默认复制目录
get_default_copy_dir() {
    local arch=$1
    
    if [[ -n "$COPY_DIR" ]]; then
        echo "$COPY_DIR"
    else
        # 确保使用纯文本，不包含颜色代码
        echo "./${BUILD_MODE}/${arch}"
    fi
}

# 处理复制逻辑
handle_copy() {
    local arch=$1
    local source_efi=$2
    local default_dir=$(get_default_copy_dir "$arch")
    local do_copy=false
    
    if [[ "$COPY_AUTO" == true ]]; then
        # 指定了 --copy，自动复制
        do_copy=true
        echo -e "${CYAN}自动复制模式（已指定 --copy）${NC}"
    else
        # 未指定 --copy，询问用户
        if ask_copy_efi "$arch" "$source_efi" "$default_dir"; then
            do_copy=true
        else
            echo -e "${YELLOW}跳过复制 $arch${NC}"
        fi
    fi
    
    if [[ "$do_copy" == true ]]; then
        copy_efi_file "$arch" "$source_efi" "$default_dir"
    fi
}

# 构建单个架构
build_arch() {
    local arch=$1
    local rust_target=$(check_target_support "$arch")
    
    if [[ -z "$rust_target" ]]; then
        echo -e "${RED}错误: 不支持的架构 '$arch'${NC}"
        return 1
    fi
    
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}构建架构: $arch ($rust_target)${NC}"
    echo -e "${BLUE}================================${NC}"
    
    # 安装目标
    install_target "$rust_target"
    
    # 设置构建命令
    local build_cmd="cargo build"
    
    if [[ "$BUILD_MODE" == "release" ]]; then
        build_cmd="$build_cmd --release"
    fi
    
    build_cmd="$build_cmd --target $rust_target"
    
    if [[ "$VERBOSE" == true ]]; then
        build_cmd="$build_cmd --verbose"
    fi
    
    # 显示构建信息
    echo -e "${YELLOW}构建模式: $BUILD_MODE${NC}"
    echo -e "${YELLOW}执行命令: $build_cmd${NC}"
    
    # 执行构建
    if $build_cmd; then
        echo -e "${GREEN}✓ $arch 构建成功${NC}"
        
        # 显示输出文件
        local target_dir="target/$rust_target"
        if [[ "$BUILD_MODE" == "release" ]]; then
            target_dir="$target_dir/release"
        else
            target_dir="$target_dir/debug"
        fi
        
        if [[ -d "$target_dir" ]]; then
            echo -e "${GREEN}输出目录: $target_dir${NC}"
            # 查找 .efi 文件
            local efi_files=$(find "$target_dir" -maxdepth 1 -name "*.efi" -type f)
            if [[ -n "$efi_files" ]]; then
                while IFS= read -r file; do
                    echo -e "  → ${CYAN}$(basename "$file")${NC}"
                done <<< "$efi_files"
                
                # 处理复制（使用第一个找到的 EFI 文件）
                local first_efi=$(echo "$efi_files" | head -n 1)
                handle_copy "$arch" "$first_efi"
            else
                echo -e "${YELLOW}警告: 未找到 .efi 文件${NC}"
            fi
        fi
        
        return 0
    else
        echo -e "${RED}✗ $arch 构建失败${NC}"
        return 1
    fi
}

# 运行测试
run_tests() {
    echo -e "${BLUE}运行测试...${NC}"
    
    if cargo test --doc; then
        echo -e "${GREEN}文档测试通过${NC}"
    else
        echo -e "${RED}文档测试失败${NC}"
        return 1
    fi
    
    # 如果有单元测试
    if grep -q "#\[cfg(test)\]" src/*.rs 2>/dev/null; then
        if cargo test --lib; then
            echo -e "${GREEN}单元测试通过${NC}"
        else
            echo -e "${RED}单元测试失败${NC}"
            return 1
        fi
    fi
    
    echo -e "${GREEN}所有测试通过${NC}"
}

# 显示复制配置
show_copy_config() {
    echo -e "${CYAN}复制配置:${NC}"
    if [[ "$COPY_AUTO" == true ]]; then
        if [[ -n "$COPY_DIR" ]]; then
            echo -e "  模式: ${GREEN}自动复制${NC}到 ${YELLOW}$COPY_DIR${NC}"
        else
            echo -e "  模式: ${GREEN}自动复制${NC}到 ${YELLOW}./$BUILD_MODE/<arch>/${NC}"
        fi
    else
        echo -e "  模式: ${YELLOW}构建后询问${NC}（默认为否）"
    fi
}

# 主函数
main() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}Rust UEFI 构建脚本${NC}"
    echo -e "${BLUE}================================${NC}"
    
    # 解析参数
    parse_args "$@"
    
    # 显示配置
    echo -e "${CYAN}构建配置:${NC}"
    echo -e "  目标架构: ${YELLOW}$TARGETS${NC}"
    echo -e "  构建模式: ${YELLOW}$BUILD_MODE${NC}"
    [[ "$CLEAN_BUILD" == true ]] && echo -e "  清理: ${YELLOW}是${NC}"
    [[ "$RUN_TESTS" == true ]] && echo -e "  运行测试: ${YELLOW}是${NC}"
    [[ "$VERBOSE" == true ]] && echo -e "  详细输出: ${YELLOW}是${NC}"
    show_copy_config
    echo ""
    
    # 检查是否在 Rust 项目中
    if [[ ! -f "Cargo.toml" ]]; then
        echo -e "${RED}错误: 未找到 Cargo.toml，请确保在 Rust 项目根目录运行${NC}"
        exit 1
    fi
    
    # 检查 UEFI 依赖
    if ! grep -q "uefi" Cargo.toml; then
        echo -e "${YELLOW}警告: Cargo.toml 中未找到 UEFI 依赖${NC}"
        echo -e "${YELLOW}建议添加: uefi = \"0.28\"${NC}"
        echo ""
    fi
    
    # 清理构建
    if [[ "$CLEAN_BUILD" == true ]]; then
        clean_build
    fi
    
    # 构建统计
    local total=0
    local success=0
    local failed=0
    
    # 构建每个架构
    for arch in $TARGETS; do
        total=$((total + 1))
        if build_arch "$arch"; then
            success=$((success + 1))
        else
            failed=$((failed + 1))
        fi
        echo ""
    done
    
    # 运行测试
    if [[ "$RUN_TESTS" == true ]]; then
        echo ""
        run_tests
    fi
    
    # 显示总结
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}构建总结${NC}"
    echo -e "${BLUE}================================${NC}"
    echo -e "总架构数: $total"
    echo -e "${GREEN}成功: $success${NC}"
    if [[ $failed -gt 0 ]]; then
        echo -e "${RED}失败: $failed${NC}"
    fi
    
    if [[ $failed -eq 0 ]] && [[ $total -gt 0 ]]; then
        echo -e "${GREEN}所有架构构建成功！${NC}"
        exit 0
    elif [[ $failed -gt 0 ]]; then
        echo -e "${RED}部分架构构建失败${NC}"
        exit 1
    fi
}

# 运行主函数
main "$@"
