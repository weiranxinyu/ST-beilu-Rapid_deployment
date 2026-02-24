#!/bin/bash

# ==============================================================================
# SillyTavern 管理模块
# ==============================================================================

# 状态显示
st_status_text() {
    if pgrep -f "node.*server.js" > /dev/null 2>&1; then
        echo -e "${GREEN}● SillyTavern 运行中${RESET} | 地址: http://127.0.0.1:8000/"
    else
        echo -e "${RED}● SillyTavern 未运行${RESET}"
    fi
}

# 启动 SillyTavern
st_start() {
    # 检查是否已在运行
    if pgrep -f "node.*server.js" > /dev/null 2>&1; then
        echo -e "${YELLOW}SillyTavern 已经在运行中${RESET}"
        echo -e "${CYAN}访问地址: http://127.0.0.1:8000/${RESET}"
        read -rsp $'按任意键继续...\n' -n 1
        return
    fi
    
    # 检查 Node.js
    if ! command -v node &>/dev/null; then
        echo -e "${RED}Node.js 未安装，请先修复环境${RESET}"
        read -rsp $'按任意键继续...\n' -n 1
        return
    fi
    
    # 检查目录
    local sillytavern_dir="$HOME/SillyTavern"
    if [[ ! -d "$sillytavern_dir" ]]; then
        echo -e "${RED}SillyTavern 未安装${RESET}"
        read -rsp $'按任意键继续...\n' -n 1
        return
    fi
    
    cd "$sillytavern_dir" || return
    
    # 检查依赖
    if [[ ! -d "node_modules" ]]; then
        echo -e "${YELLOW}未检测到依赖，正在安装...${RESET}"
        npm install --no-audit --no-fund --loglevel=error --omit=dev
    fi
    
    # 初始化日志
    if declare -f init_realtime_log > /dev/null; then
        init_realtime_log
    fi
    
    # 显示启动横幅
    if declare -f show_start_banner > /dev/null; then
        show_start_banner
    else
        clear
        echo -e "${CYAN}=== SillyTavern 启动 ====${RESET}"
    fi
    
    local start_time=$(date +%s)
    
    # 启动并监控输出
    if declare -f beautify_log_line > /dev/null; then
        npm start 2>&1 | while IFS= read -r line; do
            beautify_log_line "$line"
            
            if [[ "$line" == *"Server running"* ]] || [[ "$line" == *"SillyTavern is listening"* ]]; then
                echo -e "\\n${GREEN}═══════════════════════════════════════${RESET}"
                echo -e "${GREEN}  ✓ SillyTavern 启动成功！${RESET}"
                echo -e "${CYAN}  访问地址: http://127.0.0.1:8000/${RESET}"
                echo -e "${GREEN}═══════════════════════════════════════${RESET}\\n"
            fi
        done
    else
        # 如果美化函数不存在，直接启动
        npm start
    fi
    
    # 停止后显示摘要
    if declare -f show_stop_summary > /dev/null; then
        show_stop_summary "$start_time"
    else
        echo -e "\\n${YELLOW}SillyTavern 已停止${RESET}"
    fi
    
    read -rsp $'按任意键继续...\n' -n 1
}

# 停止 SillyTavern
st_stop() {
    echo -e "${BLUE}正在停止 SillyTavern...${RESET}"
    
    local pids=$(pgrep -f "node.*server.js" || true)
    if [[ -n "$pids" ]]; then
        echo "$pids" | while read pid; do
            kill -TERM "$pid" 2>/dev/null || true
        done
        sleep 2
        
        # 强制终止
        pids=$(pgrep -f "node.*server.js" || true)
        if [[ -n "$pids" ]]; then
            echo "$pids" | while read pid; do
                kill -KILL "$pid" 2>/dev/null || true
            done
        fi
        
        echo -e "${GREEN}SillyTavern 已停止${RESET}"
        
        # 记录日志
        if declare -f write_log > /dev/null; then
            write_log "INFO" "SillyTavern 已手动停止"
        fi
    else
        echo -e "${YELLOW}SillyTavern 未在运行${RESET}"
    fi
    
    read -rsp $'按任意键继续...\n' -n 1
}

# 重启 SillyTavern
st_restart() {
    st_stop
    sleep 1
    st_start
}

# 查看日志
st_logs() {
    echo -e "\\n${CYAN}==== SillyTavern 运行日志 ====${RESET}"
    
    if [[ -f "$REALTIME_LOG" ]]; then
        echo -e "${CYAN}日志路径: $REALTIME_LOG${RESET}\\n"
        tail -n 100 "$REALTIME_LOG"
        echo -e "\\n${CYAN}提示: 日志保存在 SillyTavern/ST-Manager-Logs/ 目录${RESET}"
    else
        echo -e "${YELLOW}暂无运行日志${RESET}"
    fi
    
    read -rsp $'按任意键继续...\n' -n 1
}

# 清理日志
st_clear_logs() {
    echo -e "\\n${CYAN}==== 清理运行日志 ====${RESET}"
    
    if [[ -f "$REALTIME_LOG" ]]; then
        local log_size=$(stat -c%s "$REALTIME_LOG" 2>/dev/null || stat -f%z "$REALTIME_LOG" 2>/dev/null || echo "0")
        local size_mb=$(awk "BEGIN {printf \"%.2f\", $log_size/1024/1024}")
        
        echo -e "${YELLOW}当前日志大小: ${size_mb} MB${RESET}"
        echo -ne "${YELLOW}确认清空? (y/n): ${RESET}"
        read -n1 confirm; echo
        
        if [[ "$confirm" =~ [yY] ]]; then
            > "$REALTIME_LOG"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] 日志已清空" >> "$REALTIME_LOG"
            echo -e "${GREEN}日志已清空${RESET}"
        fi
    else
        echo -e "${YELLOW}暂无日志${RESET}"
    fi
    
    read -rsp $'按任意键继续...\n' -n 1
}

# 打开目录
st_open_dir() {
    local st_dir="$HOME/SillyTavern"
    if [[ -d "$st_dir" ]]; then
        echo -e "${CYAN}SillyTavern 目录: $st_dir${RESET}"
        echo -e "${CYAN}数据目录: $st_dir/data${RESET}"
        echo -e "${CYAN}角色卡目录: $st_dir/public/characters${RESET}"
        echo -e "${CYAN}聊天记录: $st_dir/public/chats${RESET}"
        
        if command -v termux-open &>/dev/null; then
            termux-open "$st_dir" 2>/dev/null || true
        fi
    else
        echo -e "${RED}SillyTavern 目录不存在${RESET}"
    fi
    
    read -rsp $'按任意键继续...\n' -n 1
}
