#!/bin/bash

while true; do
    # 显示选项菜单
    echo "请选择一个操作："
    echo "1) 安装挖矿软件"
    echo "2) 查看日志"
    echo "3) 重启服务"
    echo "4) 停止服务"
    echo "5) 查看钱包地址"
    echo "6) 修改钱包地址"
    echo "7) 修改CPU占用(核心数)"
    echo "8) 设置开机自启动"
    echo "9) 移除开机自启动"
    echo "10) 退出脚本"
    read -rp "请输入选项编号 (1-10): " option

    # 检查是否要退出脚本
    if [[ "$option" == "10" ]]; then
        echo "退出脚本..."
        break
    fi

    case $option in
        1)
            # 安装环境并配置挖矿软件
            echo "更新并安装必要的包..."
            apt update -y && apt upgrade -y && apt install -y \
            build-essential libtool autotools-dev automake pkg-config \
            bsdmainutils python3 libevent-dev libboost-dev libsqlite3-dev \
            libssl-dev curl wget htop git net-tools cmake autoconf \
            libuv1-dev libhwloc-dev

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
            cd /root/shaipot
            echo "当前目录: $(pwd)"

            echo "正在编译 shaipot 挖矿程序..."
            cargo rustc --release -- -C opt-level=3 -C target-cpu=native -C codegen-units=1 -C debuginfo=0

            if [ $? -ne 0 ]; then
                echo "编译失败。请检查错误信息。"
                continue
            fi

            # 返回到 /root 目录
            cd /root

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
            # 重启服务
            echo "正在重启 Shaicoin 挖矿服务..."
            systemctl restart shai
            echo "Shaicoin 挖矿服务已成功重启。"
            ;;

        4)
            # 停止服务
            echo "正在停止 Shaicoin 挖矿服务..."
            systemctl stop shai
            echo "Shaicoin 挖矿服务已成功停止。"
            ;;

        5)
            # 查看当前钱包地址
            wallet_address=$(grep -oP '(?<=--address )\S+' /etc/systemd/system/shai.service)
            if [[ -n "$wallet_address" ]]; then
                echo "当前钱包地址为: $wallet_address"
            else
                echo "无法从服务文件中提取钱包地址。"
            fi
            ;;

        6)
            # 修改钱包地址，先提取矿池地址和线程数
            pool_address=$(grep -oP '(?<=--pool )\S+' /etc/systemd/system/shai.service)
            thread_count=$(grep -oP '(?<=--threads )\S+' /etc/systemd/system/shai.service)
            
            if [[ -z "$pool_address" ]]; then
                echo "无法从服务文件中提取矿池地址。"
                continue
            fi
            
            if [[ -z "$thread_count" ]]; then
                echo "无法从服务文件中提取线程数，默认为$(nproc)核。"
                thread_count=$(nproc)
            fi

            while true; do
                read -rp "请输入新的 Shaicoin 钱包地址: " wallet_address
                if [[ ${#wallet_address} -eq 42 ]]; then
                    echo "新的钱包地址: $wallet_address"
                    echo "正在创建新的 systemd 服务文件..."
                    bash -c 'cat > /etc/systemd/system/shai.service <<EOF
[Unit]
Description=Shaicoin Mining Service
After=network.target

[Service]
ExecStart=/root/shaipot/target/release/shaipot --address '"$wallet_address"' --pool '"$pool_address"' --threads '"$thread_count"' --vdftime 1.5
WorkingDirectory=/root/shaipot
StandardOutput=journal
StandardError=journal
Restart=always
RestartSec=10
Environment=RUST_BACKTRACE=1

[Install]
WantedBy=multi-user.target
EOF'

                    echo "刷新 systemd 配置并重启服务..."
                    systemctl daemon-reload
                    systemctl restart shai
                    echo "钱包地址已更新，服务已重新启动。"
                    break
                else
                    echo "错误：钱包地址不正确。请确保地址为42位。"
                fi
            done
            ;;

        7)
            # 修改CPU占用(核心数)，先提取矿池和钱包地址
            wallet_address=$(grep -oP '(?<=--address )\S+' /etc/systemd/system/shai.service)
            pool_address=$(grep -oP '(?<=--pool )\S+' /etc/systemd/system/shai.service)
            
            if [[ -z "$wallet_address" ]]; then
                echo "无法从服务文件中提取钱包地址。"
                continue
            fi
            
            if [[ -z "$pool_address" ]]; then
                echo "无法从服务文件中提取矿池地址。"
                continue
            fi

            while true; do
                read -rp "请输入要使用的核心数: " thread_count
                if [[ "$thread_count" =~ ^[0-9]+$ ]] && [[ "$thread_count" -gt 0 ]]; then
                    echo "设置核心数为: $thread_count"
                    bash -c 'cat > /etc/systemd/system/shai.service <<EOF
[Unit]
Description=Shaicoin Mining Service
After=network.target

[Service]
ExecStart=/root/shaipot/target/release/shaipot --address '"$wallet_address"' --pool '"$pool_address"' --threads '"$thread_count"' --vdftime 1.5
WorkingDirectory=/root/shaipot
StandardOutput=journal
StandardError=journal
Restart=always
RestartSec=10
Environment=RUST_BACKTRACE=1

[Install]
WantedBy=multi-user.target
EOF'

                    echo "刷新 systemd 配置并重启服务..."
                    systemctl daemon-reload
                    systemctl restart shai
                    echo "核心数已更新，服务已重新启动。"
                    break
                else
                    echo "错误：请输入一个大于0的数字。"
                fi
            done
            ;;

        8)
            # 设置服务为开机自启动
            echo "设置 Shaicoin 挖矿服务为开机自启动..."
            systemctl enable shai
            echo "Shaicoin 挖矿服务已设置为开机自启动。"
            ;;

        9)
            # 移除服务的开机自启动
            echo "移除 Shaicoin 挖矿服务的开机自启动..."
            systemctl disable shai
            echo "Shaicoin 挖矿服务的开机自启动已移除。"
            ;;

        *)
            echo "无效选项，请输入 1 到 10 之间的数字。"
            ;;
    esac

    echo -e "\n"
done
