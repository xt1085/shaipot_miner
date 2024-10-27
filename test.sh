#!/bin/bash

while true; do
    echo -e "\n请选择一个操作："
    
    echo -e "\n1) 安装软件"
    echo "2) 查看日志"
    echo "3) 重启服务"
    echo "4) 停止服务"
    echo "5) 查看钱包地址"
    echo "6) 修改钱包地址"
    
    echo -e "\n7) 查看矿池地址"
    echo "8) 修改矿池地址"
    echo "9) 可用矿池列表"
    echo "10) 修改CPU占用"
    echo "11) 设置开机自启"
    echo "12) 移除开机自启"
    
    echo -e "\n13) 退出脚本"

    read -rp "请输入选项编号 (1-13): " option

    if [[ "$option" == "13" ]]; then
        echo "退出脚本..."
        break
    fi

    case $option in
        1)
            if [[ "$OSTYPE" == "darwin"* ]]; then
                if ! command -v brew &> /dev/null; then
                    echo "Homebrew 未安装，您想安装哪个版本？"
                    echo "1) 原版 Homebrew"
                    echo "2) 国内加速版 Homebrew"
                    read -rp "请输入选项编号 (1-2): " brew_option

                    case $brew_option in
                        1)
                            echo "正在安装原版 Homebrew..."
                            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                            ;;
                        2)
                            echo "正在安装国内加速版 Homebrew..."
                            /bin/bash -c "$(curl -fsSL https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)"
                            ;;
                        *)
                            echo "无效选项，取消 Homebrew 安装。"
                            continue
                            ;;
                    esac
                fi

                echo "更新并安装必要的包..."
                brew update && brew install \
                automake libtool pkg-config cmake git rust
            else
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
            fi

            while true; do
                read -rp "请输入您的 Shaicoin 钱包地址: " wallet_address
                if [[ ${#wallet_address} -eq 42 ]]; then
                    echo "输入的钱包地址: $wallet_address"
                    break
                else
                    echo "错误：钱包地址不正确。请确保地址为42位。"
                fi
            done

            if [ -d "$HOME/shaipot" ]; then
                echo "$HOME/shaipot 目录已存在，正在删除..."
                rm -rf "$HOME/shaipot"
            fi

            echo "正在克隆 shaipot 仓库..."
            git clone https://github.com/shaicoin/shaipot.git "$HOME/shaipot"

            cd "$HOME/shaipot"
            echo "当前目录: $(pwd)"

            echo "正在编译 shaipot 挖矿程序..."
            cargo rustc --release -- -C opt-level=3 -C target-cpu=native -C codegen-units=1 -C debuginfo=0

            if [ $? -ne 0 ]; then
                echo "编译失败。请检查错误信息。"
                continue
            fi

            cd "$HOME"

            echo "正在创建启动脚本..."
            if [[ "$OSTYPE" == "darwin"* ]]; then
                cat > "$HOME/start_shai_mining.sh" <<EOF
#!/bin/bash
$HOME/shaipot/target/release/shaipot --address "$wallet_address" --pool wss://pool.shaicoin.org --threads $(sysctl -n hw.ncpu) --vdftime 1.5
EOF
                chmod +x "$HOME/start_shai_mining.sh"
                echo "可以通过运行 $HOME/start_shai_mining.sh 来启动 Shaicoin 挖矿程序。"
            else
                cat > /etc/systemd/system/shai.service <<EOF
[Unit]
Description=Shaicoin Mining Service
After=network.target

[Service]
ExecStart=$HOME/shaipot/target/release/shaipot --address "$wallet_address" --pool wss://pool.shaicoin.org --threads $(nproc) --vdftime 1.5
WorkingDirectory=$HOME/shaipot
StandardOutput=journal
StandardError=journal
Restart=always
RestartSec=10
Environment=RUST_BACKTRACE=1

[Install]
WantedBy=multi-user.target
EOF

                echo "刷新 systemd 配置并启动服务..."
                systemctl daemon-reload
                systemctl start shai
                systemctl enable shai
                echo "Shaipot 挖矿程序已作为服务启动并启用。"
            fi
            ;;

        2)
            if [[ "$OSTYPE" == "darwin"* ]]; then
                echo "macOS 上暂不支持使用 systemd 查看日志，请手动检查日志文件。"
            else
                echo "显示 Shaicoin 挖矿服务日志..."
                journalctl -u shai -f
            fi
            ;;

        3)
            if [[ "$OSTYPE" == "darwin"* ]]; then
                echo "macOS 上无法重启 systemd 服务，请手动重启程序。"
            else
                echo "正在重启 Shaicoin 挖矿服务..."
                systemctl restart shai
                echo "Shaicoin 挖矿服务已成功重启。"
            fi
            ;;

        4)
            if [[ "$OSTYPE" == "darwin"* ]]; then
                echo "macOS 上无法停止 systemd 服务，请手动停止程序。"
            else
                echo "正在停止 Shaicoin 挖矿服务..."
                systemctl stop shai
                echo "Shaicoin 挖矿服务已成功停止。"
            fi
            ;;

        5)
            if [[ "$OSTYPE" == "darwin"* ]]; then
                echo "macOS 上请手动检查启动脚本中的钱包地址。"
            else
                wallet_address=$(grep -oP '(?<=--address )\S+' /etc/systemd/system/shai.service)
                if [[ -n "$wallet_address" ]]; then
                    echo "当前钱包地址为: $wallet_address"
                else
                    echo "无法从服务文件中提取钱包地址。"
                fi
            fi
            ;;

        *)
            echo "无效选项，请输入 1 到 13 之间的数字。"
            ;;
    esac

    echo -e "\n"
done
