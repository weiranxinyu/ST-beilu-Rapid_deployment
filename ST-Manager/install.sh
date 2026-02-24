#!/bin/bash

# Project: ST-Manager
# Description: SillyTavern Deployment Tool for Termux with Version Selection
# Repo: https://github.com/weiranxinyu/ST-beilu-Rapid_deployment

set -euo pipefail
IFS=$'\n\t'

# =========================================================================
# 配置
# =========================================================================
REPO_URL="https://github.com/SillyTavern/SillyTavern"  # SillyTavern 官方仓库
INSTALL_DIR="$HOME/ST-Manager"
TEMP_DIR="$(mktemp -d)"
TOTAL_STEPS=6  # 增加步骤数到 6（新增版本选择步骤）

# =========================================================================
# 彩色输出定义（增强版）
# =========================================================================
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
MAGENTA='\033[1;35m'
BOLD='\033[1m'
RESET='\033[0m'

# =========================================================================
# 步骤显示函数
# =========================================================================
current_step=0

show_step() {
    current_step=$((current_step + 1))
    local step_title="$1"
    echo -e "\n${CYAN}${BOLD}==== 步骤 ${current_step}/${TOTAL_STEPS}：${step_title} ====${RESET}"
}

step_done() {
    local message="${1:-完成}"
    echo -e "${GREEN}${BOLD}>> 步骤 ${current_step}/${TOTAL_STEPS} ${message}。${RESET}"
}

step_skip() {
    local reason="$1"
    echo -e "${YELLOW}${BOLD}>> 步骤 ${current_step}/${TOTAL_STEPS} 跳过：${reason}。${RESET}"
}

info() {
    echo -e "${CYAN}${BOLD}>> $1${RESET}"
}

success() {
    echo -e "${GREEN}${BOLD}>> $1${RESET}"
}

warn() {
    echo -e "${YELLOW}${BOLD}>> $1${RESET}"
}

err() {
    echo -e "${RED}${BOLD}>> 错误：$1${RESET}" >&2
    exit 1
}

press_any_key() {
    echo -e "${CYAN}${BOLD}>> 按任意键继续...${RESET}"
    read -n1 -s
}

# =========================================================================
# 清理函数
# =========================================================================
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# =========================================================================
# 步骤 1/6：环境检测与依赖检查
# =========================================================================
check_environment() {
    show_step "环境检测与依赖检查"
    
    # Termux 环境检测
    if [ -z "$PREFIX" ] || [[ "$PREFIX" != *"/com.termux"* ]]; then
        warn "检测到非 Termux 环境，部分功能可能受限"
    else
        info "Termux 环境检测通过"
        
        # 存储权限检测
        local storage_dir="$HOME/storage/shared"
        if [ ! -d "$storage_dir" ]; then
            warn "未检测到存储权限，尝试自动获取..."
            if command -v termux-setup-storage >/dev/null 2>&1; then
                termux-setup-storage
                info "请在弹出的窗口中点击“允许”授权，正在等待..."
                local max_wait=15
                for ((i=0; i<max_wait; i++)); do
                    [ -d "$storage_dir" ] && break
                    sleep 1
                done
                if [ -d "$storage_dir" ]; then
                    success "存储权限已成功获取"
                else
                    warn "存储权限获取超时，部分功能可能受限"
                fi
            else
                warn "termux-setup-storage 命令不存在"
            fi
        else
            info "存储权限已配置"
        fi
    fi
    
    # 依赖检查
    info "检查依赖项..."
    local deps=(curl unzip git jq expect python openssl-tool)
    local missing=()
    
    # 检查 nodejs
    if ! command -v node &>/dev/null; then 
        missing+=("nodejs")
    else
        info "nodejs 已安装，跳过"
    fi
    
    for dep in "${deps[@]}"; do
        local cmd="$dep"
        [[ "$dep" == "openssl-tool" ]] && cmd="openssl"
        if ! command -v "$cmd" &>/dev/null; then 
            missing+=("$dep")
        else
            info "$dep 已安装，跳过"
        fi
    done
    
    if [ "${#missing[@]}" -gt 0 ]; then
        info "正在安装缺失的依赖：${missing[*]}"
        if [[ "$PREFIX" == *"/com.termux"* ]]; then
            pkg update -y
            pkg install -y "${missing[@]}" || err "依赖安装失败"
        else
            if command -v apt &>/dev/null; then
                sudo apt update -y
                sudo apt install -y "${missing[@]}"
            else
                warn "非 Termux 且 apt 不存在，请手动安装：${missing[*]}"
            fi
        fi
        success "依赖安装完成"
    else
        info "所有依赖已就绪"
    fi
    
    step_done "完成：环境检测与依赖检查通过"
}

# =========================================================================
# 步骤 2/6：下载 ST-Manager 项目资源
# =========================================================================
download_manager_resources() {
    show_step "下载 ST-Manager 项目资源"
    
    local manager_repo="https://github.com/weiranxinyu/ST-beilu-Rapid_deployment"
    
    info "正在从 GitHub 克隆 ST-Manager 仓库..."
    if ! git clone --depth 1 "$manager_repo" "$TEMP_DIR/repo"; then
        err "Git 克隆失败，请检查网络连接"
    fi
    success "仓库克隆成功"
    
    local source_dir="$TEMP_DIR/repo/ST-Manager"
    if [ ! -d "$source_dir" ]; then
        err "仓库结构无效：未找到 ST-Manager 文件夹"
    fi
    
    info "验证资源完整性..."
    if [ -f "$source_dir/core.sh" ]; then
        success "核心文件验证通过"
    else
        err "核心文件 core.sh 不存在"
    fi
    
    step_done "完成：ST-Manager 资源已下载"
}

# =========================================================================
# 步骤 3/6：安装 ST-Manager
# =========================================================================
install_manager() {
    show_step "安装 ST-Manager"
    
    # 备份现有配置
    if [ -f "$INSTALL_DIR/conf/settings.conf" ]; then
        info "检测到现有配置，正在备份..."
        cp "$INSTALL_DIR/conf/settings.conf" "$TEMP_DIR/settings.conf.bak"
        success "配置已备份"
    fi
    
    # 清理旧版本
    if [ -d "$INSTALL_DIR" ]; then
        info "正在移除旧版本..."
        rm -rf "$INSTALL_DIR"
        success "旧版本已清理"
    fi
    
    # 安装文件
    info "正在安装文件到 $INSTALL_DIR..."
    mkdir -p "$INSTALL_DIR"
    cp -rf "$TEMP_DIR/repo/ST-Manager/." "$INSTALL_DIR/"
    success "文件安装完成"
    
    # 恢复配置
    if [ -f "$TEMP_DIR/settings.conf.bak" ]; then
        info "正在恢复用户配置..."
        mkdir -p "$INSTALL_DIR/conf"
        cp "$TEMP_DIR/settings.conf.bak" "$INSTALL_DIR/conf/settings.conf"
        success "配置已恢复"
    fi
    
    # 设置权限
    info "设置执行权限..."
    chmod +x "$INSTALL_DIR/core.sh"
    find "$INSTALL_DIR/modules" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    success "权限设置完成"
    
    step_done "完成：ST-Manager 安装结束"
}

# =========================================================================
# 步骤 4/6：版本选择（从第一个脚本嵌入的核心功能）
# =========================================================================
select_sillytavern_version() {
    show_step "选择 SillyTavern 版本"
    
    local st_dir="$HOME/SillyTavern"
    
    # 检查是否已存在 SillyTavern
    if [ -d "$st_dir/.git" ]; then
        warn "检测到已存在 SillyTavern 目录"
        echo -ne "${CYAN}${BOLD}>> 是否重新安装/切换版本? (y/n): ${RESET}"
        read -n1 confirm; echo
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            step_skip "用户选择保留现有版本"
            return
        fi
        rm -rf "$st_dir"
    fi
    
    # 克隆仓库（浅克隆以获取标签列表）
    info "正在获取 SillyTavern 版本列表..."
    mkdir -p "$st_dir"
    if ! git clone --depth 1 --no-single-branch "$REPO_URL" "$st_dir" 2>/dev/null; then
        err "SillyTavern 仓库克隆失败"
    fi
    
    cd "$st_dir" || err "进入目录失败"
    
    # 获取所有标签
    info "正在获取版本标签..."
    git fetch --tags 2>/dev/null || warn "无法获取远程标签，使用本地标签"
    
    # 显示版本选择菜单
    echo -e "\n${CYAN}${BOLD}==== 可用版本 ====${RESET}"
    echo -e "${YELLOW}${BOLD}0. release 分支（最新开发版）${RESET}"
    
    # 获取标签列表并显示
    local tags=()
    local tag_count=0
    while IFS= read -r tag; do
        if [ -n "$tag" ]; then
            tag_count=$((tag_count + 1))
            tags+=("$tag")
            local tag_date=$(git log -1 --format=%ai "$tag" 2>/dev/null | cut -d' ' -f1 || echo "未知日期")
            echo -e "${GREEN}${BOLD}${tag_count}. ${tag} (${tag_date})${RESET}"
        fi
    done < <(git tag --sort=-creatordate | head -20)  # 显示最近20个标签
    
    echo -e "${CYAN}${BOLD}===================${RESET}"
    
    # 用户选择
    local choice
    while true; do
        echo -ne "${CYAN}${BOLD}>> 请输入版本序号 (0-${tag_count}): ${RESET}"
        read -r choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 0 ] && [ "$choice" -le "$tag_count" ]; then
            break
        else
            warn "无效输入，请重新输入"
        fi
    done
    
    # 切换到选定版本
    if [ "$choice" -eq 0 ]; then
        info "选择安装 release 分支..."
        git checkout -f origin/release 2>/dev/null || git checkout -f release 2>/dev/null || {
            # 如果 release 分支不存在，使用默认分支
            git checkout -f HEAD
        }
        success "已切换到 release 分支"
    else
        local selected_tag="${tags[$((choice-1))]}"
        info "选择安装版本: ${selected_tag}"
        
        # 切换到指定标签
        if ! git checkout -f "tags/${selected_tag}" 2>/dev/null; then
            err "切换到版本 ${selected_tag} 失败"
        fi
        success "已切换到版本 ${selected_tag}"
    fi
    
    # 清理 git 历史以节省空间（可选）
    rm -rf .git
    
    step_done "完成：版本选择结束"
}

# =========================================================================
# 步骤 5/6：安装 SillyTavern 依赖
# =========================================================================
install_sillytavern_deps() {
    show_step "安装 SillyTavern 依赖"
    
    local st_dir="$HOME/SillyTavern"
    
    if [ ! -d "$st_dir" ]; then
        step_skip "SillyTavern 目录不存在"
        return
    fi
    
    cd "$st_dir" || err "进入 SillyTavern 目录失败"
    
    # 清理旧依赖
    if [ -d "node_modules" ]; then
        info "清理旧依赖..."
        rm -rf node_modules
    fi
    
    # 清理 npm 缓存
    if [ -d "$HOME/.npm/_cacache" ]; then
        npm cache clean --force 2>/dev/null || true
    fi
    
    # 安装依赖（带重试机制）
    export NODE_ENV=production
    local retry_count=0
    local max_retries=3
    local install_success=0
    
    while [ $retry_count -lt $max_retries ]; do
        if [ $retry_count -eq 0 ]; then
            info "正在安装 SillyTavern 依赖，请耐心等待..."
        else
            warn "重试安装依赖（第 ${retry_count} 次）..."
        fi
        
        if npm install --no-audit --no-fund --loglevel=error --omit=dev; then
            install_success=1
            break
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                warn "依赖安装失败，正在清理缓存并准备重试..."
                rm -rf node_modules 2>/dev/null || true
                npm cache clean --force 2>/dev/null || true
                sleep 3
            fi
        fi
    done
    
    if [ $install_success -eq 1 ]; then
        success "SillyTavern 依赖安装完成"
    else
        err "依赖安装失败，已重试 ${max_retries} 次，请检查网络连接"
    fi
    
    step_done "完成：依赖安装结束"
}

# =========================================================================
# 步骤 6/6：创建系统命令与自动启动配置
# =========================================================================
setup_commands() {
    show_step "创建系统命令与自动启动配置"
    
    # 创建全局命令
    if [ -d "$PREFIX/bin" ]; then
        info "创建全局命令 'st-menu'..."
        cat > "$PREFIX/bin/st-menu" << 'EOF'
#!/bin/bash
bash $HOME/ST-Manager/core.sh
EOF
        chmod +x "$PREFIX/bin/st-menu"
        success "全局命令 'st-menu' 已创建"
    else
        warn "未检测到 $PREFIX/bin 目录，跳过全局命令创建"
    fi
    
    # 自动启动配置（交互式）
    echo -e "\n${CYAN}${BOLD}>> 是否配置 Termux 启动时自动运行 ST-Manager？${RESET}"
    read -rp "启用自动启动? (y/n): " choice
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        local bashrc="$HOME/.bashrc"
        local cmd="bash $INSTALL_DIR/core.sh"
        
        # 检查是否已存在
        if grep -q "$cmd" "$bashrc" 2>/dev/null; then
            step_skip "自动启动已配置"
        else
            echo "$cmd" >> "$bashrc"
            success "自动启动已启用"
        fi
    else
        info "已跳过自动启动配置"
    fi
    
    step_done "完成：命令配置结束"
}

# =========================================================================
# 安装完成总结
# =========================================================================
finish_installation() {
    echo -e "\n${GREEN}${BOLD}========================================${RESET}"
    success "ST-Manager 与 SillyTavern 安装成功！"
    echo -e "${CYAN}${BOLD}>> ST-Manager 路径：${RESET}$INSTALL_DIR"
    echo -e "${CYAN}${BOLD}>> SillyTavern 路径：${RESET}$HOME/SillyTavern"
    echo -e "${CYAN}${BOLD}>> 启动方式：${RESET}"
    echo -e "   • 全局命令：${YELLOW}st-menu${RESET}"
    echo -e "   • 完整路径：${YELLOW}bash $INSTALL_DIR/core.sh${RESET}"
    echo -e "${GREEN}${BOLD}========================================${RESET}"
    
    # 询问是否立即启动
    echo -e "\n${CYAN}${BOLD}>> 是否立即启动 ST-Manager？${RESET}"
    read -rp "立即启动? (y/n): " start
    if [[ "$start" == "y" || "$start" == "Y" ]]; then
        success "正在启动 ST-Manager..."
        echo -e "\n${CYAN}${BOLD}>> 按任意键继续...${RESET}"
        read -n1 -s
        exec bash "$INSTALL_DIR/core.sh"
    else
        info "安装完成，您可以随时使用 'st-menu' 命令启动"
    fi
}

# =========================================================================
# 主程序入口
# =========================================================================
main() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo "╔════════════════════════════════════════╗"
    echo "║         ST-Manager 安装程序            ║"
    echo "║    SillyTavern Termux 快速部署工具      ║"
    echo "║         支持版本选择功能               ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${RESET}"
    
    check_environment
    download_manager_resources
    install_manager
    select_sillytavern_version      # 新增：版本选择步骤
    install_sillytavern_deps        # 新增：安装依赖步骤
    setup_commands
    finish_installation
}

main "$@"
