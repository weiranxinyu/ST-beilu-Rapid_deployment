#!/bin/bash

# SillyTavern 管理模块

st_status_text() {
    if pgrep -f "node.*server.js" > /dev/null 2>&1; then
        echo -e "${GREEN}● SillyTavern 运行中${RESET} | 地址: http://127.0.0.1:8000/"
    else
        echo -e "${RED}● SillyTavern 未运行${RESET}"
    fi
}

st_start() {
    if pgrep -f "node.*server.js" > /dev/null 2>&1; then
        warn "SillyTavern 已经在运行中"
        echo -e "${CYAN}访问地址: http://127.0.0.1:8000/${RESET}"
        pause
        return
    fi
    
    if ! command -v node &>/dev/null; then
        err "Node.js 未安装，请先修复环境"
        pause
        return
    fi
    
    local sillytavern_dir="$HOME/SillyTavern"
    if [[ ! -d "$sillytavern_dir" ]]; then
        err "SillyTavern 未安装"
        pause
        return
    fi
    
    cd "$sillytavern_dir" || return
    
    if [[ ! -d "node_modules" ]]; then
        warn "未检测到依赖，正在安装..."
        npm install --no-audit --no-fund --loglevel=error --omit=dev
    fi
    
    init_realtime_log
    show_start_banner
    
    local start_time=$(date +%s)
    
    npm start 2>&1 | while IFS= read -r line; do
        beautify_log_line "$line"
        
        if [[ "$line" == *"Server running"* ]] || [[ "$line" == *"SillyTavern is listening"* ]]; then
            echo -e "\\n${LOG_COLOR_SUCCESS}═══════════════════════════════════════════════════════════════${RESET}"
            echo -e "${LOG_COLOR_SUCCESS}  ✓ SillyTavern 启动成功！${RESET}"
            echo -e "${LOG_COLOR_INFO}  访问地址: http://127.0.0.1:8000/${RESET}"
            echo -e "${LOG_COLOR_SUCCESS}═══════════════════════════════════════════════════════════════${RESET}\\n"
        fi
    done
    
    show_stop_summary "$start_time"
    pause
}

st_stop() {
    log "正在停止 SillyTavern..."
    
    local pids=$(pgrep -f "node.*server.js" || true)
    if [[ -n "$pids" ]]; then
        echo "$pids" | while read pid; do
            kill -TERM "$pid" 2>/dev/null || true
        done
        sleep 2
        
        pids=$(pgrep -f "node.*server.js" || true)
        if [[ -n "$pids" ]]; then
            echo "$pids" | while read pid; do
                kill -KILL "$pid" 2>/dev/null || true
            done
        fi
        
        success "SillyTavern 已停止"
        write_log "INFO" "SillyTavern 已手动停止"
    else
        warn "SillyTavern 未在运行"
    fi
    pause
}

st_restart() {
    st_stop
    sleep 1
    st_start
}

st_logs() {
    echo -e "\\n${CYAN}${BOLD}==== SillyTavern 实时运行日志 ====${RESET}"
    
    if [[ -f "$REALTIME_LOG" ]]; then
        local total_lines=$(wc -l < "$REALTIME_LOG" 2>/dev/null || echo "0")
        local log_size=$(stat -c%s "$REALTIME_LOG" 2>/dev/null || stat -f%z "$REALTIME_LOG" 2>/dev/null || echo "0")
        local size_mb=$(awk "BEGIN {printf \"%.2f\", $log_size/1024/1024}")
        
        echo -e "${CYAN}日志路径: $REALTIME_LOG${RESET}"
        echo -e "${CYAN}日志大小: ${size_mb} MB | 总行数: $total_lines${RESET}\\n"
        
        echo -e "${YELLOW}最近 100 行日志:${RESET}\\n"
        tail -n 100 "$REALTIME_LOG"
        
        echo -e "\\n${CYAN}提示: 完整日志保存在手机存储的 SillyTavern/ST-Manager-Logs/ 目录${RESET}"
    else
        echo -e "${YELLOW}暂无运行日志${RESET}"
    fi
    pause
}

st_clear_logs() {
    echo -e "\\n${CYAN}${BOLD}==== 清理实时日志 ====${RESET}"
    
    if [[ -f "$REALTIME_LOG" ]]; then
        local log_size=$(stat -c%s "$REALTIME_LOG" 2>/dev/null || stat -f%z "$REALTIME_LOG" 2>/dev/null || echo "0")
        local size_mb=$(awk "BEGIN {printf \"%.2f\", $log_size/1024/1024}")
        
        echo -e "${YELLOW}当前日志大小: ${size_mb} MB${RESET}"
        echo -ne "${YELLOW}确认清空? (y/n): ${RESET}"
        read -n1 confirm; echo
        
        if [[ "$confirm" =~ [yY] ]]; then
            > "$REALTIME_LOG"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] 日志已清空" >> "$REALTIME_LOG"
            success "日志已清空"
        fi
    else
        echo -e "${YELLOW}暂无日志${RESET}"
    fi
    pause
}

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
        err "SillyTavern 目录不存在"
    fi
    pause
}
