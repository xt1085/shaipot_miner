#!/bin/bash

while true; do
    # Display options menu
    echo "Select an operation:"
    echo "1) Install mining software"
    echo "2) View logs"
    echo "3) Restart service"
    echo "4) Stop service"
    echo "5) Enable autostart on boot"
    echo "6) Disable autostart on boot"
    echo "7) Change wallet address"
    echo "8) Exit script"
    read -rp "Enter option number (1-8): " option

    # Check if exiting the script
    if [[ "$option" == "8" ]]; then
        echo "Exiting script..."
        break
    fi

    case $option in
        1)
            # Install environment and configure mining software
            echo "Updating and installing required packages..."
            apt update -y && apt upgrade -y && apt install -y pkg-config libssl-dev curl wget htop sudo git net-tools build-essential cmake automake libtool autoconf libuv1-dev libhwloc-dev

            echo "Installing Rust and Cargo..."
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

            if [ $? -ne 0 ]; then
                echo "Rust installation failed. Please check network connection or installation output."
                continue
            fi

            echo "Updating environment variables..."
            source "$HOME/.cargo/env"

            if ! command -v cargo &> /dev/null; then
                echo "Cargo not found. Please manually add Rust install path to PATH."
                echo 'Add the following line to ~/.bashrc or ~/.zshrc to fix:'
                echo 'export PATH="$HOME/.cargo/bin:$PATH"'
                continue
            fi

            echo "Verifying Rust and Cargo installation..."
            rustc --version
            cargo --version
            echo "Rust and Cargo successfully installed!"

            # Enter wallet address with validation
            while true; do
                read -rp "Enter your Shaicoin wallet address: " wallet_address
                if [[ ${#wallet_address} -eq 42 ]]; then
                    echo "Wallet address entered: $wallet_address"
                    break
                else
                    echo "Error: Incorrect wallet address. Ensure it is 42 characters."
                fi
            done

            # Remove /root/shaipot directory if it exists
            if [ -d "/root/shaipot" ]; then
                echo "/root/shaipot directory exists. Removing..."
                rm -rf /root/shaipot
            fi

            # Clone latest shaipot repository
            echo "Cloning shaipot repository..."
            git clone https://github.com/shaicoin/shaipot.git /root/shaipot

            # Enter project directory
            cd /root/shaipot
            echo "Current directory: $(pwd)"

            echo "Compiling shaipot mining program..."
            cargo rustc --release -- -C opt-level=3 -C target-cpu=native -C codegen-units=1 -C debuginfo=0

            if [ $? -ne 0 ]; then
                echo "Compilation failed. Please check error messages."
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

            echo "Reloading systemd configuration and starting service..."
            systemctl daemon-reload
            systemctl start shai
            systemctl enable shai
            echo "Shaipot mining program started and enabled as a service."
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
            echo "Shaicoin mining service restarted successfully."
            ;;

        4)
            # Stop service
            echo "Stopping Shaicoin mining service..."
            systemctl stop shai
            echo "Shaicoin mining service stopped successfully."
            ;;

        5)
            # Enable service on boot
            echo "Enabling Shaicoin mining service to start on boot..."
            systemctl enable shai
            echo "Shaicoin mining service set to start on boot."
            ;;

        6)
            # Disable service on boot
            echo "Disabling Shaicoin mining service autostart..."
            systemctl disable shai
            echo "Shaicoin mining service autostart removed."
            ;;

        7)
            # Change wallet address by regenerating service file
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

                    echo "Reloading systemd configuration and restarting service..."
                    systemctl daemon-reload
                    systemctl restart shai
                    echo "Wallet address updated, and service restarted."
                    break
                else
                    echo "Error: Incorrect wallet address. Ensure it is 42 characters."
                fi
            done
            ;;

        *)
            echo "Invalid option. Please enter a number between 1 and 8."
            ;;
    esac

    echo -e "\n"
done
