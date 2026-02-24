#!/bin/bash

# ==============================================================================
# Project: ST-Manager
# Description: Advanced SillyTavern Deployment Tool for Termux
# Version: v1.0
# Author: 贝露凛倾
# ==============================================================================

# Environment Setup
set -o pipefail

# ==============================================================================
# Paths & Variables
# ==============================================================================
SCRIPT_NAME="st-manager"
DIR=$(cd "$(dirname "$0")" && pwd)
APP_DIR="$DIR"
CONF_DIR="$DIR/conf"
MODULES_DIR="$DIR/modules"
SETTINGS_FILE="$CONF_DIR/settings.conf"

# Colors
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[36m'
CYAN='\033[1;36m'
MAGENTA='\033[1;35m'
BOLD='\033[1m'
RESET='\033[0m'

# 实时日志颜色（新增）
LOG_COLOR_DEBUG='\033[38;5;240m'
LOG_COLOR_INFO='\033[38;5;39m'
LOG_COLOR_SUCCESS='\033[38;5;82m'
LOG_COLOR_WARN='\033[38;5;208m'
LOG_COLOR_ERROR='\033[38;5;196m'
LOG_COLOR_SYSTEM='\033[38;5;141m'
LOG_COLOR_TIME='\033[38;5;248m'
LOG_COLOR_EMOJI='\033[38;5;229m'

# ==============================================================================
# 日志系统（修改：和备份文件夹一样，在共享存储中）
# ==============================================================================
LOG_DIR="/storage/emulated/0/SillyTavern/ST-Manager-Logs"
LOG_FILE="$LOG_DIR/st-manager.log"
REALTIME_LOG="$LOG_DIR/sillytavern-runtime.log"

# 检查并获取存储权限
check_storage_permission() {
    local storage_dir="/storage/emulated/0"
    if [ ! -d "$storage_dir" ]; then
        warn "未检测到存储权限，尝试获取..."
        if command -v termux-setup-storage >/dev/null 2>&1; then
            termux-setup-storage
            sleep 2
        fi
    fi
}

# 初始化日志
init_log() {
    check_storage_permission
    
    local st_dir="/storage/emulated/0/SillyTavern"
    if [[ ! -d "$st_dir" ]]; then
        mkdir -p "$st_dir" 2>/dev/null || {
            LOG_DIR="$APP_DIR/logs"
            LOG_FILE="$LOG_DIR/st-manager.log"
            REALTIME_LOG="$LOG_DIR/sillytavern-runtime.log"
            mkdir -p "$LOG_DIR"
            return
        }
    fi
    
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR" 2>/dev/null || {
            LOG_DIR="$APP_DIR/logs"
            LOG_FILE="$LOG_DIR/st-manager.log"
            REALTIME_LOG="$LOG_DIR/sillytavern-runtime.log"
            mkdir -p "$LOG_DIR"
        }
    fi
}

# 写入日志
write_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null || true
}

# 记录操作开始
log_start() {
    local operation="$1"
    init_log
    write_log "INFO" "========================================"
    write_log "INFO" "操作开始: $operation"
    echo -e "${CYAN}${BOLD}>> 操作已记录到日志: $LOG_FILE${RESET}"
}

# 记录操作结束
log_end() {
    local status="$1"
    local detail="${2:-}"
    write_log "INFO" "操作结果: $status"
    [[ -n "$detail" ]] && write_log "INFO" "详情: $detail"
    write_log "INFO" "========================================"
}

# 初始化实时日志（新增）
init_realtime_log() {
    init_log
    mkdir -p "$LOG_DIR" 2>/dev/null || true
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] === SillyTavern 实时日志开始 ===" >> "$REALTIME_LOG" 2>/dev/null || true
}

# 查看日志
view_logs() {
    echo -e "\\n${CYAN}${BOLD}==== 查看操作日志 ====${RESET}"
    log_start "查看操作日志"
    
    init_log
    
    if [[ ! -f "$LOG_FILE" ]]; then
        echo -e "${YELLOW}${BOLD}>> 暂无日志记录${RESET}"
        echo -e "${CYAN}${BOLD}>> 日志路径: $LOG_FILE${RESET}"
        log_end "失败" "日志文件不存在"
        pause
        return
    fi
    
    local fi
    
    local total_lines=$(wc -l < "$LOG_FILE" 2>/dev/null || echo "0")
    local log_size=$(stat -c%s "$LOG_FILE" 2>/dev/null || stat -f%z "$LOG_FILE" 2>/dev/null || echo "0")
    local size_mb=$(awk "BEGIN {printf \"%.2f\", $log_size/1024/1024}")
    
    echo -e "${CYAN}${BOLD}>> 日志路径: $LOG_FILE${RESET}"
    echo -e "${CYAN}${BOLD}>> 日志大小: ${size_mb} MB | 总行数: $total_lines${RESET}\\n"
    
    echo -e "${GREEN}${BOLD}========== 最近 50 行日志 ==========${RESET}"
    tail -n 50 "$LOG_FILE"
    echo -e "${GREEN}${BOLD}========== 日志结束 ==========${RESET}\\n"
    
    echo -e "${CYAN}${BOLD}>> 最近的操作记录:${RESET}"
    grep "操作开始:" "$LOG_FILE" 2>/dev/null | tail -n 5 | while read line; do
        echo -e "  ${YELLOW}$line${RESET}"
    done
    
    echo -e "\\n${YELLOW}${BOLD}>> 提示: 日志文件位于手机存储的 SillyTavern/ST-Manager-Logs/ 目录${RESET}"
    
    log_end "成功" "查看日志完成"
    pause
}

# 清理日志
clear_logs() {
    echo -e "\\n${CYAN}${BOLD}==== 清理日志文件 ====${RESET}"
    
    init_log
    
    if [[ ! -f "$LOG_FILE" ]]; then
        echo -e "${YELLOW}${BOLD}>> 暂无日志${RESET}"
        pause
        return
    fi
    
    local log_size=$(stat -c%s "$LOG_FILE" 2>/dev/null || stat -f%z "$LOG_FILE" 2>/dev/null || echo "0")
    local size_mb=$(awk "BEGIN {printf \"%.2f\", $log_size/1024/1024}")
    
    echo -e "${YELLOW}${BOLD}>> 当前日志大小: ${size_mb} MB${RESET}"
    echo -e "${CYAN}${BOLD}>> 日志路径: $LOG_FILE${RESET}"
    echo -ne "${YELLOW}${BOLD}>> 确认清空日志? (y/n): ${RESET}"
    read -n1 confirm; echo
    
    if [[ "$confirm" =~ [yY] ]]; then
        > "$LOG_FILE"
        write_log "INFO" "日志已清空"
        echo -e "${GREEN}${BOLD}>> 日志已清空${RESET}"
    else
        echo -e "${YELLOW}${BOLD}>> 已取消${RESET}"
    fi
    pause
}

# Core Arrays for Dynamic Menu
declare -A MENU_TEXTS
declare -A FUNCTION_MAP
declare -A MODULE_GROUPS
declare -A MODULE_GROUP_ORDER
declare -A GROUP_TO_MODULE_MAP

# Menu Order Definition
readonly MAIN_GROUP_ORDER=("SillyTavern 管理" "gcli2api 管理" "系统管理")
MENU_ORDER=()
RELOAD_MENU=false

# ==============================================================================
# Utility Functions
# ==============================================================================
log() { echo -e "${BLUE}[INFO] $1${RESET}"; }
success() { echo -e "${GREEN}[SUCCESS] $1${RESET}"; }
warn() { echo -e "${YELLOW}[WARN] $1${RESET}"; }
err() { echo -e "${RED}[ERROR] $1${RESET}" >&2; }

pause() {
    read -rsp $'按任意键继续...\n' -n 1
}

# ==============================================================================
# Settings Management
# ==============================================================================
load_settings() {
    if [[ ! -f "$SETTINGS_FILE" ]]; then
        mkdir -p "$CONF_DIR"
        echo "# ST-Manager Configuration" > "$SETTINGS_FILE"
        echo "USE_PROXY=false" >> "$SETTINGS_FILE"
        echo "PROXY_URL=" >> "$SETTINGS_FILE"
        echo "DEBUG_MODE=false" >> "$SETTINGS_FILE"
    fi
    source "$SETTINGS_FILE"

    # Apply Proxy
    if [[ "$USE_PROXY" == "true" && -n "$PROXY_URL" ]]; then
        export http_proxy="$PROXY_URL"
        export https_proxy="$PROXY_URL"
        export ALL_PROXY="$PROXY_URL"
        log "已启用代理: $PROXY_URL"
    else
        unset http_proxy https_proxy ALL_PROXY
    fi
}

save_settings() {
    {
        echo "USE_PROXY=\"$USE_PROXY\""
        echo "PROXY_URL=\"$PROXY_URL\""
        echo "DEBUG_MODE=\"$DEBUG_MODE\""
    } > "$SETTINGS_FILE"
}

# ==============================================================================
# Module System (The Core Logic)
# ==============================================================================
validate_menu_conf() {
    local menu_file="$1"
    if [[ ! -f "$menu_file" ]]; then return 1; fi
    return 0
}

load_modules() {
    # Reset arrays
    MENU_TEXTS=()
    FUNCTION_MAP=()
    MODULE_GROUPS=()
    MODULE_GROUP_ORDER=()

    local module_dir
    for module_dir in "$MODULES_DIR"/*/; do
        [[ -d "$module_dir" ]] || continue

        local module_name=$(basename "$module_dir")
        local funcs_file="${module_dir}functions.sh"
        local menu_file="${module_dir}menu.conf"

        if [[ ! -f "$funcs_file" || ! -f "$menu_file" ]]; then
            continue
        fi

        # Load functions
        source "$funcs_file"

        # Parse menu.conf
        local current_group=""
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Skip comments and empty lines
            [[ "$line" =~ ^[[:space:]]*# || -z "$line" ]] && continue

            # Group Header: [GroupName]
            if [[ "$line" =~ ^\[(.*)\] ]]; then
                current_group="${BASH_REMATCH[1]}"
                current_group="${current_group%$'\r'}"
                GROUP_TO_MODULE_MAP["$current_group"]="$module_name"

            # Menu Item: key=value
            elif [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
                local key="${BASH_REMATCH[1]}"
                local text="${BASH_REMATCH[2]}"

                key=$(echo "$key" | tr -d '[:space:]')
                text=$(echo "$text" | tr -d '\r')

                MENU_TEXTS["$key"]="$text"
                FUNCTION_MAP["$key"]="$key"
                MODULE_GROUPS["$current_group,$key"]="$text"

                if [[ -z "${MODULE_GROUP_ORDER[$current_group]}" ]]; then
                    MODULE_GROUP_ORDER["$current_group"]="$key"
                else
                    MODULE_GROUP_ORDER["$current_group"]="${MODULE_GROUP_ORDER[$current_group]} $key"
                fi
            fi
        done < "$menu_file"
    done

    # Add System Management Items
    local sys_group="系统管理"
    local sys_items=("fix_env:修复运行环境" "update_self:更新管理工具" "settings_menu:系统设置" "version_switch:酒馆版本切换" "view_logs:查看操作日志" "clear_logs:清理日志文件" "visit_github:访问 GitHub (求星星)" "visit_discord:加入 Discord 粉丝群")

    for item in "${sys_items[@]}"; do
        local key="${item%:*}"
        local text="${item#*:}"
        MENU_TEXTS["$key"]="$text"
        FUNCTION_MAP["$key"]="$key"
        MODULE_GROUPS["$sys_group,$key"]="$text"
    done
    MODULE_GROUP_ORDER["$sys_group"]="fix_env update_self settings_menu version_switch view_logs clear_logs visit_github visit_discord"
}

# ==============================================================================
# System Functions
# ==============================================================================
fix_env() {
    echo -e "${YELLOW}正在重新安装依赖...${RESET}"
    log_start "修复运行环境"
    
    if [[ "$PREFIX" == *"/com.termux"* ]]; then
        pkg update -y
        pkg install -y curl unzip git nodejs-lts jq expect python openssl-tool procps inotify-tools

        if ! command -v pm2 &>/dev/null; then
            echo -e "${YELLOW}正在安装 PM2 进程管理器...${RESET}"
            npm install -g pm2
        fi
    else
        warn "非 Termux 环境，跳过 pkg 安装。"
    fi
    
    success "依赖修复完成。"
    log_end "成功" "依赖修复完成"
    pause
}

update_self() {
    echo -e "${BLUE}正在检查更新...${RESET}"
    log_start "更新管理工具"
    
    cd "$APP_DIR" || return

    if [[ "$USE_PROXY" == "true" && -n "$PROXY_URL" ]]; then
        git config http.proxy "$PROXY_URL"
        git config https.proxy "$PROXY_URL"
    else
        git config --unset http.proxy
        git config --unset https.proxy
    fi

    if git pull; then
        success "更新成功！正在重启..."
        log_end "成功" "更新成功"
        exec bash "$0"
    else
        echo -e "${RED}更新失败！错误信息如上。${RESET}"
        write_log "ERROR" "更新失败"
        echo -e "${YELLOW}常见原因:${RESET}"
        echo -e "1. 网络问题 (请检查代理设置)"
        echo -e "2. 本地文件冲突 (您修改了脚本文件)"

        read -rp "是否尝试强制重置更新? (这将覆盖本地修改) [y/N]: " force
        if [[ "$force" =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}正在强制重置...${RESET}"
            git fetch --all
            git reset --hard origin/main
            success "重置成功！正在重启..."
            log_end "成功" "强制重置更新"
            exec bash "$0"
        fi
        log_end "失败" "更新失败"
        pause
    fi
}

settings_menu() {
    while true; do
        clear
        echo -e "${BLUE}=== 系统设置 ===${RESET}"
        echo -e "${YELLOW}注意: 如果您在中国大陆使用，更新功能通常需要配置代理。${RESET}"
        echo -e "请查看您的 VPN 软件设置，找到 'HTTP 代理端口'。"
        echo -e "常见的本地代理地址: http://127.0.0.1:7890 (Clash) 或 :10809 (v2rayN)"
        echo -e "${BLUE}----------------------------------------------${RESET}"
        echo -e "1) 切换代理开关 (当前: $USE_PROXY)"
        echo -e "2) 设置代理地址 (当前: $PROXY_URL)"
        echo -e "0) 返回"
        read -rp "请选择: " choice
        case "$choice" in
            1)
                if [[ "$USE_PROXY" == "true" ]]; then USE_PROXY="false"; else USE_PROXY="true"; fi
                save_settings
                ;;
            2)
                echo -e "${YELLOW}请输入完整的代理地址 (包含 http://)${RESET}"
                read -rp "例如 http://127.0.0.1:7890 : " url
                PROXY_URL="$url"
                save_settings
                ;;
            0) break ;;
        esac
    done
}

# ==============================================================================
# 版本切换功能
# ==============================================================================
show_version_tags() {
    echo -e "\\n${CYAN}${BOLD}==== 查看版本标签 ====${RESET}"
    log_start "查看版本标签"
    
    cd "$HOME/SillyTavern" 2>/dev/null || { 
        echo -e "${RED}${BOLD}>> SillyTavern 目录不存在${RESET}"
        write_log "ERROR" "SillyTavern 目录不存在"
        log_end "失败" "目录不存在"
        pause
        return
    }
    
    if [[ ! -d ".git" ]]; then
        echo -e "${RED}${BOLD}>> 不是有效的 Git 仓库${RESET}"
        write_log "ERROR" "不是有效的 Git 仓库"
        log_end "失败" "不是 Git 仓库"
        pause
        cd "$HOME"
        return
    fi
    
    local current=$(git describe --tags --exact-match 2>/dev/null || echo "release 分支")
    echo -e "${YELLOW}${BOLD}>> 当前版本: ${current}${RESET}"
    write_log "INFO" "当前版本: $current"
    
    echo -e "${CYAN}${BOLD}>> 正在获取版本列表...${RESET}"
    git fetch --tags 2>/dev/null || {
        echo -e "${YELLOW}${BOLD}>> 无法连接远程，显示本地标签${RESET}"
        write_log "WARN" "无法获取远程标签"
    }
    
    echo -e "\\n${CYAN}${BOLD}==== 可用版本标签 ====${RESET}"
    local count=0
    while IFS= read -r tag; do
        [[ -n "$tag" ]] && {
            count=$((count + 1))
            local date=$(git log -1 --format=%ai "$tag" 2>/dev/null | cut -d' ' -f1 || echo "未知")
            echo -e "${GREEN}${BOLD}${count}. ${tag} (${date})${RESET}"
        }
    done < <(git tag --sort=-creatordate | head -20)
    
    local total=$(git tag | wc -l)
    echo -e "${CYAN}${BOLD}========================${RESET}"
    echo -e "${CYAN}${BOLD}>> 共 $total 个版本${RESET}"
    
    log_end "成功" "显示版本标签"
    pause
    cd "$HOME"
}

switch_tavern_version() {
    echo -e "\\n${CYAN}${BOLD}==== 切换 SillyTavern 版本 ====${RESET}"
    log_start "切换 SillyTavern 版本"
    
    cd "$HOME/SillyTavern" 2>/dev/null || { 
        echo -e "${RED}${BOLD}>> SillyTavern 目录不存在${RESET}"
        write_log "ERROR" "目录不存在"
        log_end "失败"
        pause
        return
    }
    
    if [[ ! -d ".git" ]]; then
        echo -e "${RED}${BOLD}>> 不是有效的 Git 仓库${RESET}"
        write_log "ERROR" "不是 Git 仓库"
        log_end "失败"
        pause
        cd "$HOME"
        return
    fi
    
    for cmd in node npm git; do
        if ! command -v $cmd >/dev/null 2>&1; then
            echo -e "${RED}${BOLD}>> 缺少依赖: $cmd${RESET}"
            write_log "ERROR" "缺少依赖: $cmd"
            log_end "失败" "缺少依赖"
            pause
            cd "$HOME"
            return
        fi
    done
    
    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        echo -e "${YELLOW}${BOLD}>> 警告: 有未提交的更改，切换将丢失！${RESET}"
        echo -ne "${YELLOW}${BOLD}>> 继续? (y/n): ${RESET}"
        read -n1 confirm; echo
        [[ "$confirm" != [yY] ]] && {
            echo -e "${YELLOW}${BOLD}>> 已取消${RESET}"
            write_log "INFO" "用户取消"
            pause
            cd "$HOME"
            return
        }
    fi
    
    local current=$(git describe --tags --exact-match 2>/dev/null || echo "release")
    echo -e "${YELLOW}${BOLD}>> 当前版本: ${current}${RESET}"
    
    git fetch --tags 2>/dev/null || true
    
    echo -e "\\n${CYAN}${BOLD}==== 可用版本 ====${RESET}"
    echo -e "${YELLOW}${BOLD}0. release 分支（最新开发版）${RESET}"
    
    local tags=()
    local idx=0
    while IFS= read -r tag; do
        [[ -n "$tag" ]] && {
            idx=$((idx + 1))
            tags+=("$tag")
            echo -e "${GREEN}${BOLD}${idx}. ${tag}${RESET}"
        }
    done < <(git tag --sort=-creatordate | head -20)
    
    echo -e "${CYAN}${BOLD}===================${RESET}"
    
    local choice
    while true; do
        echo -ne "${CYAN}${BOLD}>> 请输入序号 (0-${idx}): ${RESET}"
        read -r choice
        [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 0 ] && [ "$choice" -le "$idx" ] && break
        echo -e "${RED}${BOLD}>> 无效输入${RESET}"
    done
    
    if [ "$choice" -eq 0 ]; then
        echo -e "${CYAN}${BOLD}>> 切换到 release 分支...${RESET}"
        if git checkout -f origin/release 2>/dev/null || git checkout -f release 2>/dev/null || git checkout -f HEAD; then
            success "已切换到 release 分支"
            write_log "INFO" "切换到 release"
        else
            echo -e "${RED}${BOLD}>> 切换失败${RESET}"
            write_log "ERROR" "切换失败"
            pause
            cd "$HOME"
            return
        fi
    else
        local selected="${tags[$((choice-1))]}"
        echo -e "${CYAN}${BOLD}>> 切换到: ${selected}${RESET}"
        write_log "INFO" "准备切换到: $selected"
        
        if git checkout -f "tags/${selected}" 2>/dev/null; then
            success "版本切换成功"
            write_log "INFO" "成功切换到: $selected"
        else
            echo -e "${RED}${BOLD}>> 切换失败${RESET}"
            write_log "ERROR" "切换失败: $selected"
            pause
            cd "$HOME"
            return
        fi
    fi
    
    echo -e "${CYAN}${BOLD}>> 重新安装依赖...${RESET}"
    export NODE_ENV=production
    rm -rf node_modules 2>/dev/null || true
    npm cache clean --force 2>/dev/null || true
    
    local retry=0
    local max=3
    local ok=0
    while [ $retry -lt $max ]; do
        [ $retry -gt 0 ] && echo -e "${YELLOW}${BOLD}>> 重试 ($retry/$max)...${RESET}"
        npm install --no-audit --no-fund --loglevel=error --omit=dev && {
            ok=1
            break
        }
        retry=$((retry + 1))
        rm -rf node_modules 2>/dev/null || true
        sleep 3
    done
    
    if [ $ok -eq 1 ]; then
        success "依赖安装完成"
        write_log "INFO" "依赖安装成功"
        log_end "成功" "版本切换完成"
    else
        echo -e "${RED}${BOLD}>> 依赖安装失败${RESET}"
        write_log "ERROR" "依赖安装失败"
        log_end "部分成功" "版本切换但依赖失败"
    fi
    
    pause
    cd "$HOME"
}

show_version_help() {
    echo -e "\\n${CYAN}${BOLD}==== 版本切换帮助 ====${RESET}"
    cat << 'EOF'

功能说明:
  SillyTavern 使用 Git 版本管理，可切换不同版本

版本类型:
  • release 分支 - 最新开发版本
  • 标签版本 - 稳定发布版本（如 1.13.4）

注意事项:
  • 切换前建议备份数据
  • 未提交的更改会丢失
  • 切换后自动重新安装依赖
  • 需要良好的网络连接

EOF
    pause
}

version_switch() {
    while true; do
        clear
        echo -e "${CYAN}${BOLD}==== 酒馆版本切换 ====${RESET}"
        echo -e "${YELLOW}${BOLD}0. 返回上级菜单${RESET}"
        echo -e "${GREEN}${BOLD}1. 查看版本标签${RESET}"
        echo -e "${BLUE}${BOLD}2. 切换酒馆版本${RESET}"
        echo -e "${MAGENTA}${BOLD}3. 版本切换帮助${RESET}"
        echo -e "${CYAN}${BOLD}======================${RESET}"
        echo -ne "${CYAN}${BOLD}请选择（0-3）：${RESET}"
        read -n1 c; echo
        
        case "$c" in
            0) break ;;
            1) show_version_tags ;;
            2) switch_tavern_version ;;
            3) show_version_help ;;
            *) echo -e "${RED}${BOLD}>> 无效选项${RESET}"; sleep 1 ;;
        esac
    done
}

visit_github() {
    local url="https://github.com/beilusaiying/ST-beilu-Rapid_deployment"
    echo -e "${BLUE}正在打开 GitHub 仓库...${RESET}"
    echo -e "请给我们点个 Star ⭐️！"
    if command -v termux-open-url &>/dev/null; then
        termux-open-url "$url"
    elif command -v xdg-open &>/dev/null; then
        xdg-open "$url" &>/dev/null
    else
        echo -e "请手动访问: $url"
    fi
    pause
}

visit_discord() {
    local url="https://discord.gg/agHeDq9bqU"
    echo -e "${BLUE}正在打开 Discord 粉丝群...${RESET}"
    if command -v termux-open-url &>/dev/null; then
        termux-open-url "$url"
    elif command -v xdg-open &>/dev/null; then
        xdg-open "$url" &>/dev/null
    else
        echo -e "请手动访问: $url"
    fi
    pause
}

# ==============================================================================
# 实时日志美化显示系统（新增）
# ==============================================================================

# 美化输出一行日志
beautify_log_line() {
    local line="$1"
    local timestamp=$(date '+%H:%M:%S')
    
    # 写入原始日志
    echo "[$timestamp] $line" >> "$REALTIME_LOG" 2>/dev/null || true
    
    # 根据内容类型美化显示
    case "$line" in
        # 成功信息
        *"successfully"*|*"Successfully"*|*"done"*|*"Done"*)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_SUCCESS}✓${RESET} ${LOG_COLOR_SUCCESS}${line}${RESET}"
            ;;
        # 错误信息
        *"error"*|*"Error"*|*"ERROR"*|*"failed"*|*"Failed"*)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_ERROR}✗${RESET} ${LOG_COLOR_ERROR}${line}${RESET}"
            ;;
        # 警告信息
        *"warn"*|*"Warn"*|*"WARN"*|*"warning"*|*"Warning"*)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_WARN}⚠${RESET} ${LOG_COLOR_WARN}${line}${RESET}"
            ;;
        # 服务器启动
        *"Server running"*|*"listening on"*|*"SillyTavern is listening"*)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_SUCCESS}🚀${RESET} ${LOG_COLOR_SUCCESS}${line}${RESET}"
            write_log "INFO" "SillyTavern 服务器已启动"
            ;;
        # URL 地址
        *"http://"*|*"https://"*|*"Go to:"*)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_INFO}🔗${RESET} ${LOG_COLOR_INFO}${line}${RESET}"
            ;;
        # 编译信息
        *"Compiling"*|*"webpack"*|*"compiled"*)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_SYSTEM}⚙${RESET} ${LOG_COLOR_SYSTEM}${line}${RESET}"
            ;;
        # 扩展/插件加载
        *"Extensions"*|*"Extension"*|*"Loading"*|*"Loaded"*)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_EMOJI}📦${RESET} ${line}"
            ;;
        # 角色卡相关
        *"character"*|*"Character"*|*"avatar"*|*"Avatar"*)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_EMOJI}👤${RESET} ${line}"
            ;;
        # 聊天相关
        *"chat"*|*"Chat"*|*"message"*|*"Message"*)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_EMOJI}💬${RESET} ${line}"
            ;;
        # API 请求
        *"Generating"*|*"generate"*|*"API"*|*"api"*|*"tokenizer"*)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_INFO}🤖${RESET} ${LOG_COLOR_INFO}${line}${RESET}"
            ;;
        # 数据复制/移动
        *"Copied"*|*"copied"*|*"Copying"*|*"copy"*)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_INFO}📋${RESET} ${line}"
            ;;
        # 图片/背景
        *"Image"*|*"image"*|*"background"*|*"Background"*)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_EMOJI}🖼${RESET} ${line}"
            ;;
        # 默认信息
        *)
            echo -e "${LOG_COLOR_TIME}[${timestamp}]${RESET} ${LOG_COLOR_INFO}ℹ${RESET} ${line}"
            ;;
    esac
}

# 显示启动横幅
show_start_banner() {
    clear
    echo -e "${LOG_COLOR_SYSTEM}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║           SillyTavern 实时运行监控                           ║"
    echo "║           Real-time Runtime Monitor                          ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
    echo -e "${LOG_COLOR_INFO}启动时间: $(date '+%Y-%m-%d %H:%M:%S')${RESET}"
    echo -e "${LOG_COLOR_INFO}日志文件: $REALTIME_LOG${RESET}"
    echo -e "${LOG_COLOR_WARN}提示: 按 Ctrl+C 停止服务器${RESET}\\n"
    echo -e "${LOG_COLOR_SYSTEM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\\n"
}

# 显示停止摘要
show_stop_summary() {
    local start_time="$1"
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    echo -e "\\n${LOG_COLOR_SYSTEM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${LOG_COLOR_WARN}SillyTavern 已停止${RESET}"
    echo -e "${LOG_COLOR_INFO}运行时长: ${minutes}分${seconds}秒${RESET}"
    echo -e "${LOG_COLOR_INFO}日志保存至: $REALTIME_LOG${RESET}"
    echo -e "${LOG_COLOR_SYSTEM}═══════════════════════════════════════════════════════════════${RESET}\\n"
    
    write_log "INFO" "SillyTavern 停止，运行时长: ${minutes}分${seconds}秒"
}

# ==============================================================================
# Main Menu
# ==============================================================================
show_banner() {
    clear
    echo -e "${BLUE}==============================================${RESET}"
    echo -e "${GREEN} 与你之歌 v1.0 ${RESET}"
    echo -e "${BLUE}==============================================${RESET}"
    echo -e "${YELLOW}作者: 贝露凛倾${RESET}"
    echo -e "${BLUE}----------------------------------------------${RESET}"
    echo -e "本人做此预设的目的为ai模型微调的学术交流，仅供学习，无其他目的。"
    echo -e "且为免费开源项目，禁止商用。二改需授权。"
    echo -e "此脚本禁止用于商业传播，仅限ai模型研究者交流。"
    echo -e "禁止利用该脚本进行违反当地法律的事情。"
    echo -e "${BLUE}==============================================${RESET}"
}

show_group_menu() {
    local group_name="$1"
    while true; do
        clear
        echo -e "${BLUE}=== $group_name ===${RESET}"

        local module_name="${GROUP_TO_MODULE_MAP[$group_name]}"
        if [[ "$module_name" == "sillytavern" ]]; then
            if declare -f st_status_text > /dev/null; then st_status_text; fi
        elif [[ "$module_name" == "gcli2api" ]]; then
            if declare -f gcli_status_text > /dev/null; then gcli_status_text; fi
        fi
        echo -e "${BLUE}----------------------------------------------${RESET}"

        local i=1
        declare -A active_options

        if [[ -n "${MODULE_GROUP_ORDER[$group_name]}" ]]; then
            for key in ${MODULE_GROUP_ORDER[$group_name]}; do
                echo -e " ${GREEN}$i)${RESET} ${MENU_TEXTS[$key]}"
                active_options[$i]="$key"
                ((i++))
            done
        fi

        echo -e "\\n${RED}0)${RESET} 返回上一级"
        echo -e "${BLUE}==============================================${RESET}"

        read -rp "请选择 [0-$((i-1))]: " choice

        if [[ "$choice" == "0" ]]; then
            break
        elif [[ -n "${active_options[$choice]}" ]]; then
            local func="${FUNCTION_MAP[${active_options[$choice]}]}"
            if declare -f "$func" > /dev/null; then
                "$func"
            else
                err "未找到功能 '$func'!"
                pause
            fi
        else
            err "无效选项"
            sleep 1
        fi
    done
}

main_menu() {
    while true; do
        show_banner

        echo -e "${YELLOW}[状态监控]${RESET}"
        if declare -f st_status_text > /dev/null; then st_status_text; fi
        if declare -f gcli_status_text > /dev/null; then gcli_status_text; fi
        echo -e "${BLUE}----------------------------------------------${RESET}"

        local i=1
        declare -A group_map

        for group in "${MAIN_GROUP_ORDER[@]}"; do
            echo -e " ${GREEN}$i)${RESET} $group"
            group_map[$i]="$group"
            ((i++))
        done

        echo -e "\\n${RED}0)${RESET} 退出"
        echo -e "${BLUE}==============================================${RESET}"

        read -rp "请选择 [0-$((i-1))]: " choice

        if [[ "$choice" == "0" ]]; then
            exit 0
        elif [[ -n "${group_map[$choice]}" ]]; then
            show_group_menu "${group_map[$choice]}"
        else
            err "无效选项"
            sleep 1
        fi
    done
}

# ==============================================================================
# Startup
# ==============================================================================
load_settings
load_modules
main_menu
