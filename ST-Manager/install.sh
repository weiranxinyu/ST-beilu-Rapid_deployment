#!/bin/bash

# Project: ST-Manager
# Description: SillyTavern Deployment Tool for Termux
# Repo: https://github.com/weiranxinyu/ST-beilu-Rapid_deployment

set -euo pipefail
IFS=$'\n\t'

# =========================================================================
# 配置
# =========================================================================
REPO_URL="https://github.com/weiranxinyu/ST-beilu-Rapid_deployment"
INSTALL_DIR="$HOME/ST-Manager"
TEMP_DIR="$(mktemp -d)"
TOTAL_STEPS=5

# =========================================================================
# 彩色输出定义（从第一个脚本引入）
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
# 步骤显示函数（从第一个脚本引入）
# =========================================================================
current_step=0

show_step() {
    current_step=$((current_step + 1))
    echo -e "\n${CYAN}${BOLD}==== 步骤 ${current_step}/${TOTAL_STEPS}：$1 ====${RESET}"
}

step_done() {
    echo -e "${GREEN}${BOLD}>> 步骤 ${current_step}/${TOTAL_STEPS} ${1:-完成}。${RESET}"
}

step_skip() {
    echo -e "${YELLOW}${BOLD}>> 步骤 ${current_step}/${TOTAL_STEPS} 跳过：$1。${RESET}"
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

log() { 
    echo -e "${BLUE}${BOLD}>> [INFO] $1${RESET}" 
}

# =========================================================================
# 清理函数
# =========================================================================
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# =========================================================================
# 步骤 1/5：环境检测与依赖检查
# =========================================================================
check_deps() {
    show_step "环境检测与依赖检查"
    
    log "检查环境中..."
    
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
                info "请在弹出的窗口中点击允许授权，正在等待..."
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
    
    step_done "环境检测与依赖检查通过"
}

# =========================================================================
# 步骤 2/5：下载项目资源
# =========================================================================
install_project() {
    show_step "下载项目资源"
    
    log "正在从 GitHub 克隆仓库..."
    if ! git clone --depth 1 "$REPO_URL" "$TEMP_DIR/repo"; then
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
    
    step_done "项目资源已下载"
}

# =========================================================================
# 步骤 3/5：安装与配置
# =========================================================================
setup_project() {
    show_step "安装与配置"
    
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
    
    step_done "安装与配置结束"
}

# =========================================================================
# 步骤 4/5：创建系统命令与自动启动
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
        
        if grep -q "$cmd" "$bashrc" 2>/dev/null; then
            step_skip "自动启动已配置"
        else
            echo "$cmd" >> "$bashrc"
            success "自动启动已启用"
        fi
    else
        info "已跳过自动启动配置"
    fi
    
    step_done "命令配置结束"
}

# =========================================================================
# 步骤 5/5：安装完成
# =========================================================================
finish_installation() {
    show_step "安装完成"
    
    echo -e "\n${GREEN}${BOLD}========================================${RESET}"
    success "ST-Manager 安装成功！"
    echo -e "${CYAN}${BOLD}>> 安装路径：${RESET}$INSTALL_DIR"
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
    
    step_done "安装流程全部结束"
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
    echo "╚════════════════════════════════════════╝"
    echo -e "${RESET}"
    
    check_deps
    install_project
    setup_project
    setup_commands
    finish_installation
}

main "$@"
