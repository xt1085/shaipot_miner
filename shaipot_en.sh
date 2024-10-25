#!/bin/bash

while true; do
    # Display options menu
    echo "Please select an operation:"
    echo "1) Install mining software"
    echo "2) View logs"
    echo "3) Restart service"
    echo "4) Stop service"
    echo "5) Enable service at startup"
    echo "6) Disable service at startup"
    echo "7) Exit script"
    read -rp "Enter option number (1-7): " option

    # Check if the user wants to exit the script
    if [[ "$option" == "7" ]]; then
        echo "Exiting script..."
        break
    fi

    case $option in
        1)
            # Install environment and configure mining software
            echo "Updating and installing necessary packages..."
            apt update -y && apt upgrade -y && apt install -y pkg-config libssl-dev curl wget htop sudo git net-tools build-essential cmake automake libtool autoconf libuv1-dev libhwloc-dev

            echo "Installing Rust and Cargo..."
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

            if [ $? -ne 0 ]; then
                echo "Rust installation failed. Please check the network connection or installation script output."
                continue
            fi

            echo "Updating environment variables..."
            source "$HOME/.cargo/env"

            if ! command -v cargo &> /dev/null; then
                echo "Cargo not found. Please manually add the Rust installation path to PATH."
                echo 'You can fix this by adding the following line to ~/.bashrc or ~/.zshrc:'
                echo 'export PATH="$HOME/.cargo/bin:$PATH"'
                continue
            fi

            echo "Verifying Rust and Cargo installation..."
            rustc --version
            cargo --version
            echo "Rust and Cargo have been successfully installed!"

            # Input wallet address and validate it
            while true; do
                read -rp "Please enter your Shaicoin wallet address: " wallet_address
                if [[ ${#wallet_address} -eq 42 ]]; then
                    echo "Entered wallet address: $wallet_address"
                    break
                else
                    echo "Error: Invalid wallet address. Ensure the address is 42 characters long."
                fi
            done

            # If /root/shaipot directory exists, delete it
            if [ -d "/root/shaipot" ]; then
                echo "/root/shaipot directory exists, deleting..."
                rm -rf /root/shaipot
            fi

            # Clone the latest shaipot repository
            echo "Cloning the shaipot repository..."
            git clone https://github.com/shaicoin/shaipot.git /root/shaipot

            # Navigate to the project directory
            cd /root/shaipot || { echo "Unable to enter /root/shaipot directory"; continue; }
            echo "Current directory: $(pwd)"

            echo "Compiling the shaipot mining program..."
            cargo rustc --release -- -C opt-level=3 -C target-cpu=native -C codegen-units=1 -C debuginfo=0

            if [ $? -ne 0 ]; then
                echo "Compilation failed. Please check for errors."
                continue
            fi

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
            echo "Shaipot mining program has been started and enabled as a service."
            ;;

        2)
            # View mining program logs
            echo "Displaying Shaicoin mining service logs..."
            journalctl -u shai -f
            ;;

        3)
            # Restart the service and check status
            echo "Restarting Shaicoin mining service..."
            systemctl restart shai

            # Check service status
            if systemctl is-active --quiet shai; then
                echo "Shaicoin mining service has been successfully restarted."
            else
                echo "Shaicoin mining service restart failed. Please check logs for more information."
            fi
            ;;

        4)
            # Stop the service
            echo "Stopping Shaicoin mining service..."
            systemctl stop shai
            sleep 1  # Ensure return to menu after stopping
            echo "Shaicoin mining service has been successfully stopped."
            ;;

        5)
            # Enable service at startup
            echo "Enabling Shaicoin mining service at startup..."
            systemctl enable shai
            echo "Shaicoin mining service has been set to start at boot."
            ;;

        6)
            # Disable service at startup
            echo "Disabling Shaicoin mining service at startup..."
            systemctl disable shai
            echo "Shaicoin mining service startup has been disabled."
            ;;

        *)
            echo "Invalid option, please enter a number from 1 to 7."
            ;;
    esac

    echo "Operation complete, returning to menu..."
done
