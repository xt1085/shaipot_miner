#!/bin/bash

while true; do
    # Display options menu
    echo "Please select an operation:"
    echo "1) Install mining software"
    echo "2) View logs"
    echo "3) Restart service"
    echo "4) Stop service"
    echo "5) View wallet address"
    echo "6) Change wallet address"
    echo "7) Adjust CPU usage (number of cores)"
    echo "8) Enable auto-start on boot"
    echo "9) Disable auto-start on boot"
    echo "10) Exit script"
    read -rp "Enter option number (1-10): " option

    # Check if user wants to exit
    if [[ "$option" == "10" ]]; then
        echo "Exiting script..."
        break
    fi

    case $option in
        1)
            # Install environment and configure mining software
            echo "Updating and installing necessary packages..."
            apt update -y && apt upgrade -y && apt install -y \
            build-essential libtool autotools-dev automake pkg-config \
            bsdmainutils python3 libevent-dev libboost-dev libsqlite3-dev \
            libssl-dev curl wget htop git net-tools cmake autoconf \
            libuv1-dev libhwloc-dev

            echo "Installing Rust and Cargo..."
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

            if [ $? -ne 0 ]; then
                echo "Rust installation failed. Please check your network connection or the installation script output."
                continue
            fi

            echo "Updating environment variables..."
            source "$HOME/.cargo/env"

            if ! command -v cargo &> /dev/null; then
                echo "Cargo not found. Please manually add Rust installation path to PATH."
                echo 'You can fix this by adding the following line to ~/.bashrc or ~/.zshrc:'
                echo 'export PATH="$HOME/.cargo/bin:$PATH"'
                continue
            fi

            echo "Verifying Rust and Cargo installation..."
            rustc --version
            cargo --version
            echo "Rust and Cargo successfully installed!"

            # Enter wallet address and validate
            while true; do
                read -rp "Enter your Shaicoin wallet address: " wallet_address
                if [[ ${#wallet_address} -eq 42 ]]; then
                    echo "Wallet address entered: $wallet_address"
                    break
                else
                    echo "Error: Invalid wallet address. Please ensure the address is 42 characters."
                fi
            done

            # Remove /root/shaipot directory if it exists
            if [ -d "/root/shaipot" ]; then
                echo "/root/shaipot directory exists, removing..."
                rm -rf /root/shaipot
            fi

            # Clone latest shaipot repository
            echo "Cloning shaipot repository..."
            git clone https://github.com/shaicoin/shaipot.git /root/shaipot

            # Enter project directory
            cd /root/shaipot
            echo "Current directory: $(pwd)"

            echo "Compiling shaipot mining software..."
            cargo rustc --release -- -C opt-level=3 -C target-cpu=native -C codegen-units=1 -C debuginfo=0

            if [ $? -ne 0 ]; then
                echo "Compilation failed. Please check the error messages."
                continue
            fi

            # Return to /root directory
            cd /root

            echo "Creating systemd service file..."
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

            echo "Reloading systemd and starting service..."
            systemctl daemon-reload
            systemctl start shai
            systemctl enable shai
            echo "Shaipot mining software started and enabled as a service."
            ;;

        2)
            # View mining software logs
            echo "Displaying Shaicoin mining service logs..."
            journalctl -u shai -f
            ;;

        3)
            # Restart service
            echo "Restarting Shaicoin mining service..."
            systemctl restart shai
            echo "Shaicoin mining service restarted successfully."
            ;;

        4)
            # Stop service
            echo "Stopping Shaicoin mining service..."
            systemctl stop shai
            echo "Shaicoin mining service stopped successfully."
            ;;

        5)
            # View current wallet address
            wallet_address=$(grep -oP '(?<=--address )\S+' /etc/systemd/system/shai.service)
            if [[ -n "$wallet_address" ]]; then
                echo "Current wallet address: $wallet_address"
            else
                echo "Could not extract wallet address from the service file."
            fi
            ;;

        6)
            # Change wallet address, retaining pool address and thread count
            pool_address=$(grep -oP '(?<=--pool )\S+' /etc/systemd/system/shai.service)
            thread_count=$(grep -oP '(?<=--threads )\S+' /etc/systemd/system/shai.service)
            
            if [[ -z "$pool_address" ]]; then
                echo "Could not extract pool address from the service file."
                continue
            fi
            
            if [[ -z "$thread_count" ]]; then
                echo "Could not extract thread count from the service file, defaulting to $(nproc) cores."
                thread_count=$(nproc)
            fi

            while true; do
                read -rp "Enter new Shaicoin wallet address: " wallet_address
                if [[ ${#wallet_address} -eq 42 ]]; then
                    echo "New wallet address: $wallet_address"
                    echo "Creating new systemd service file..."
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

                    echo "Reloading systemd and restarting service..."
                    systemctl daemon-reload
                    systemctl restart shai
                    echo "Wallet address updated and service restarted."
                    break
                else
                    echo "Error: Invalid wallet address. Please ensure the address is 42 characters."
                fi
            done
            ;;

        7)
            # Adjust CPU usage (number of cores), retaining pool address and wallet address
            wallet_address=$(grep -oP '(?<=--address )\S+' /etc/systemd/system/shai.service)
            pool_address=$(grep -oP '(?<=--pool )\S+' /etc/systemd/system/shai.service)
            
            if [[ -z "$wallet_address" ]]; then
                echo "Could not extract wallet address from the service file."
                continue
            fi
            
            if [[ -z "$pool_address" ]]; then
                echo "Could not extract pool address from the service file."
                continue
            fi

            while true; do
                read -rp "Enter the number of cores to use: " thread_count
                if [[ "$thread_count" =~ ^[0-9]+$ ]] && [[ "$thread_count" -gt 0 ]]; then
                    echo "Setting number of cores to: $thread_count"
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

                    echo "Reloading systemd and restarting service..."
                    systemctl daemon-reload
                    systemctl restart shai
                    echo "Core count updated and service restarted."
                    break
                else
                    echo "Error: Please enter a positive integer."
                fi
            done
            ;;

        8)
            # Enable auto-start on boot
            echo "Enabling Shaicoin mining service to auto-start on boot..."
            systemctl enable shai
            echo "Shaicoin mining service is set to auto-start on boot."
            ;;

        9)
            # Disable auto-start on boot
            echo "Disabling auto-start on boot for Shaicoin mining service..."
            systemctl disable shai
            echo "Auto-start on boot for Shaicoin mining service has been disabled."
            ;;

        *)
            echo "Invalid option. Please enter a number between 1 and 10."
            ;;
    esac

    echo -e "\n"
done
