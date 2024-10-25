#!/bin/bash

while true; do
    # 显示选项菜单
    echo "请选择一个操作："
    echo "1) 安装挖矿软件"
    echo "2) 查看日志"
    echo "3) 重启服务"
    echo "4) 停止服务"
    echo "5) 设置开机自启动"
    echo "6) 移除开机自启动"
    echo "7) 退出脚本"
    read -rp "请输入选项编号 (1-7): " option

    # 检查是否要退出脚本
    if [[ "$option" == "7" ]]; then
        echo "退出脚本..."
        break
    fi

    case $option in
        1)
            # 安装环境并配置挖矿软件
            echo "更新并安装必要的包..."
            apt update -y && apt upgrade -y && apt install -y pkg-config libssl-dev curl wget htop sudo git net-tools build-essential cmake automake libtool autoconf libuv1-dev libhwloc-dev

            echo "正在安装 Rust 和 Cargo..."
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

            if [ $? -ne 0 ]; then
                echo "Rust 安装失败。请检查网络连接或安装脚本的输出。"
                continue
            fi

            echo "更新环境变量..."
            source "$HOME/.cargo/env"

            if ! command -v cargo &> /dev/null; then
                echo "Cargo 未找到，请手动将 Rust 安装路径添加到 PATH 中。"
                echo '可以通过在 ~/.bashrc 或 ~/.zshrc 中添加以下行来解决：'
                echo 'export PATH="$HOME/.cargo/bin:$PATH"'
                continue
            fi

            echo "验证 Rust 和 Cargo 安装..."
            rustc --version
            cargo --version
            echo "Rust 和 Cargo 已成功安装！"

            # 输入钱包地址并进行验证
            while true; do
                read -rp "请输入您的 Shaicoin 钱包地址: " wallet_address
                if [[ ${#wallet_address} -eq 42 ]]; then
                    echo "输入的钱包地址: $wallet_address"
                    break
                else
                    echo "错误：钱包地址不正确。请确保地址为42位。"
                fi
            done

            # 如果 /root/shaipot 目录存在，则删除
            if [ -d "/root/shaipot" ]; then
                echo "/root/shaipot 目录已存在，正在删除..."
                rm -rf /root/shaipot
            fi

            # 克隆最新的 shaipot 仓库
            echo "正在克隆 shaipot 仓库..."
            git clone https://github.com/shaicoin/shaipot.git /root/shaipot

            # 进入项目目录
            cd /root/shaipot || { echo "无法进入 /root/shaipot 目录"; continue; }
            echo "当前目录: $(pwd)"

            echo "正在编译 shaipot 挖矿程序..."
            cargo rustc --release -- -C opt-level=3 -C target-cpu=native -C codegen-units=1 -C debuginfo=0

            if [ $? -ne 0 ]; then
                echo "编译失败。请检查错误信息。"
                continue
            fi

            echo "正在创建 systemd 服务文件..."
            bash -c 'cat > /etc/systemd/system/shai.service <<EOF
[Unit]
Description=Shaicoin Mining Service
After=network.target

[Service]
ExecStart=/root/shaipot/target/release/shaipot --address '"$wallet_address"' --pool wss://pool.shaicoin.org --threads $(nproc) --vdftime 1.5
WorkingDirectory=/root/shaipot
StandardOutput=journal
StandardError=journal
Restart=always
RestartSec=10
Environment=RUST_BACKTRACE=1

[Install]
WantedBy=multi-user.target
EOF'

            echo "刷新 systemd 配置并启动服务..."
            systemctl daemon-reload
            systemctl start shai
            systemctl enable shai
            echo "Shaipot 挖矿程序已作为服务启动并启用。"
            ;;

        2)
            # 查看挖矿程序日志
            echo "显示 Shaicoin 挖矿服务日志..."
            journalctl -u shai -f
            ;;

        3)
            # 重启服务并检查状态
            echo "正在重启 Shaicoin 挖矿服务..."
            systemctl restart shai

            # 检查服务状态
            if systemctl is-active --quiet shai; then
                echo "Shaicoin 挖矿服务已成功重启。"
            else
                echo "Shaicoin 挖矿服务重启失败。请检查日志获取详细信息。"
            fi
            ;;

        4)
            # 停止服务
            echo "正在停止 Shaicoin 挖矿服务..."
            systemctl stop shai
            sleep 1  # 确保停止后返回菜单
            echo "Shaicoin 挖矿服务已成功停止。"
            ;;

        5)
            # 设置服务为开机自启动
            echo "设置 Shaicoin 挖矿服务为开机自启动..."
            systemctl enable shai
            echo "Shaicoin 挖矿服务已设置为开机自启动。"
            ;;

        6)
            # 移除服务的开机自启动
            echo "移除 Shaicoin 挖矿服务的开机自启动..."
            systemctl disable shai
            echo "Shaicoin 挖矿服务的开机自启动已移除。"
            ;;

        *)
            echo "无效选项，请输入 1 到 7 之间的数字。"
            ;;
    esac

    echo "操作完成，返回菜单..."
done
