#!/bin/bash

while true; do
    # Display options menu
    echo -e "\nSelect an option:"
    
    echo -e "\n1) Install software"
    echo "2) View logs"
    echo "3) Restart service"
    echo "4) Stop service"
    echo "5) View wallet address"
    echo "6) Change wallet address"
    
    echo -e "\n7) View pool address"
    echo "8) Change pool address"
    echo "9) Available pool list"
    echo "10) Change CPU usage"
    echo "11) Enable startup on boot"
    echo "12) Disable startup on boot"
    
    echo -e "\n13) Exit script"

    read -rp "Enter option number (1-13): " option

    # Check if we should exit the script
    if [[ "$option" == "13" ]]; then
        echo "Exiting script..."
        break
    fi

    case $option in
        1)
            # Install required packages and configure mining software
            echo "Updating and installing necessary packages..."
            apt update -y && apt upgrade -y && apt install -y \
            build-essential libtool autotools-dev automake pkg-config \
            bsdmainutils python3 libevent-dev libboost-dev libsqlite3-dev \
            libssl-dev curl wget htop git net-tools cmake autoconf \
            libuv1-dev libhwloc-dev

            echo "Installing Rust and Cargo..."
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

            if [ $? -ne 0 ]; then
                echo "Rust installation failed. Please check your network connection or the script output."
                continue
            fi

            echo "Updating environment variables..."
            source "$HOME/.cargo/env"

            if ! command -v cargo &> /dev/null; then
                echo "Cargo not found. Please manually add Rust installation path to PATH."
                echo 'To fix, add the following line to ~/.bashrc or ~/.zshrc:'
                echo 'export PATH="$HOME/.cargo/bin:$PATH"'
                continue
            fi

            echo "Verifying Rust and Cargo installation..."
            rustc --version
            cargo --version
            echo "Rust and Cargo successfully installed!"

            # Input wallet address and validate it
            while true; do
                read -rp "Enter your Shaicoin wallet address: " wallet_address
                if [[ ${#wallet_address} -eq 42 ]]; then
                    echo "Wallet address entered: $wallet_address"
                    break
                else
                    echo "Error: Incorrect wallet address. Please ensure the address is 42 characters long."
                fi
            done

            # Remove /root/shaipot directory if it exists
            if [ -d "/root/shaipot" ]; then
                echo "/root/shaipot directory exists, removing it..."
                rm -rf /root/shaipot
            fi

            # Clone the latest shaipot repository
            echo "Cloning shaipot repository..."
            git clone https://github.com/shaicoin/shaipot.git /root/shaipot

            # Enter project directory
            cd /root/shaipot
            echo "Current directory: $(pwd)"

            echo "Compiling shaipot mining software..."
            cargo rustc --release -- -C opt-level=3 -C target-cpu=native -C codegen-units=1 -C debuginfo=0

            if [ $? -ne 0 ]; then
                echo "Compilation failed. Please check the error message."
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

            echo "Reloading systemd configuration and starting the service..."
            systemctl daemon-reload
            systemctl start shai
            systemctl enable shai
            echo "Shaipot mining software is running as a service and enabled on boot."
            ;;

        2)
            # View mining program logs
            echo "Displaying Shaicoin mining service logs..."
            journalctl -u shai -f
            ;;

        3)
            # Restart service
            echo "Restarting Shaicoin mining service..."
            systemctl restart shai
            echo "Shaicoin mining service successfully restarted."
            ;;

        4)
            # Stop service
            echo "Stopping Shaicoin mining service..."
            systemctl stop shai
            echo "Shaicoin mining service successfully stopped."
            ;;

        5)
            # View current wallet address
            wallet_address=$(grep -oP '(?<=--address )\S+' /etc/systemd/system/shai.service)
            if [[ -n "$wallet_address" ]]; then
                echo "Current wallet address: $wallet_address"
            else
                echo "Unable to retrieve wallet address from the service file."
            fi
            ;;

        6)
            # Change wallet address, first retrieve pool address and thread count
            pool_address=$(grep -oP '(?<=--pool )\S+' /etc/systemd/system/shai.service)
            thread_count=$(grep -oP '(?<=--threads )\S+' /etc/systemd/system/shai.service)
            
            if [[ -z "$pool_address" ]]; then
                echo "Unable to retrieve pool address from the service file."
                continue
            fi
            
            if [[ -z "$thread_count" ]]; then
                echo "Unable to retrieve thread count, defaulting to $(nproc) cores."
                thread_count=$(nproc)
            fi

            while true; do
                read -rp "Enter new Shaicoin wallet address: " wallet_address
                if [[ ${#wallet_address} -eq 42 ]]; then
                    echo "New wallet address: $wallet_address"
                    echo "Creating a new systemd service file..."
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

                    echo "Reloading systemd configuration and restarting the service..."
                    systemctl daemon-reload
                    systemctl restart shai
                    echo "Wallet address updated, service restarted."
                    break
                else
                    echo "Error: Incorrect wallet address. Please ensure it is 42 characters long."
                fi
            done
            ;;

        7)
            # View current pool address
            pool_address=$(grep -oP '(?<=--pool )\S+' /etc/systemd/system/shai.service)
            if [[ -n "$pool_address" ]]; then
                echo "Current pool address: $pool_address"
            else
                echo "Unable to retrieve pool address from the service file."
            fi
            ;;

        8)
            # Change pool address, first retrieve wallet address and CPU usage
            wallet_address=$(grep -oP '(?<=--address )\S+' /etc/systemd/system/shai.service)
            thread_count=$(grep -oP '(?<=--threads )\S+' /etc/systemd/system/shai.service)
            
            if [[ -z "$wallet_address" ]]; then
                echo "Unable to retrieve wallet address from the service file."
                continue
            fi
            
            if [[ -z "$thread_count" ]]; then
                echo "Unable to retrieve thread count, defaulting to $(nproc) cores."
                thread_count=$(nproc)
            fi

            while true; do
                read -rp "Enter new Shaicoin pool address: " pool_address
                if [[ -n "$pool_address" ]]; then
                    echo "New pool address: $pool_address"
                    echo "Creating a new systemd service file..."
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

                    echo "Reloading systemd configuration and restarting the service..."
                    systemctl daemon-reload
                    systemctl restart shai
                    echo "Pool address updated, service restarted."
                    break
                else
                    echo "Error: Pool address cannot be empty."
                fi
            done
            ;;

        9)
            # Available pool list
            echo "Available pool list:"
            echo -e "\nPool address: wss://pool.shaicoin.org\nWebsite: https://pool.shaicoin.org\n"
            echo -e "Pool address: wss://shaipool.moncici.xyz/ws/\nWebsite: https://shaipool.moncici.xyz\n"
            echo -e "Pool address: ws://162.220.160.74:3333\nWebsite: https://shaipool.z4ch.xyz\n"
            echo -e "Pool address: wss://pool.shaicoin.fun\nWebsite: https://www.shaicoin.fun\n"
            ;;

        10)
            # Change CPU usage, first retrieve pool and wallet address
            wallet_address=$(grep -oP '(?<=--address )\S+' /etc/systemd/system/shai.service)
            pool_address=$(grep -oP '(?<=--pool )\S+' /etc/systemd/system/shai.service)
            
            if [[ -z "$wallet_address" ]]; then
                echo "Unable to retrieve wallet address from the service file."
                continue
            fi
            
            if [[ -z "$pool_address" ]]; then
                echo "Unable to retrieve pool address from the service file."
                continue
            fi

            while true; do
                read -rp "Enter the number of cores to use: " thread_count
                if [[ "$thread_count" =~ ^[0-9]+$ ]] && [[ "$thread_count" -gt 0 ]]; then
                    echo "Setting core count to: $thread_count"
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

                    echo "Reloading systemd configuration and restarting the service..."
                    systemctl daemon-reload
                    systemctl restart shai
                    echo "Core count updated, service restarted."
                    break
                else
                    echo "Error: Please enter a number greater than 0."
                fi
            done
            ;;

        11)
            # Enable startup on boot
            echo "Enabling Shaicoin mining service on boot..."
            systemctl enable shai
            echo "Shaicoin mining service is set to start on boot."
            ;;

        12)
            # Disable startup on boot
            echo "Disabling Shaicoin mining service on boot..."
            systemctl disable shai
            echo "Shaicoin mining service will not start on boot."
            ;;

        *)
            echo "Invalid option, please enter a number between 1 and 13."
            ;;
    esac

    echo -e "\n"
done
