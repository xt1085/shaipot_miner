#!/bin/bash

while true; do
    # Display options menu
    echo "Please select an option:"
    echo "1) Install mining software"
    echo "2) View logs"
    echo "3) Restart service"
    echo "4) Stop service"
    echo "5) Enable service at startup"
    echo "6) Disable service at startup"
    echo "7) Exit script"
    read -rp "Enter option number (1-7): " option

    # Check if the script should exit
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
                echo "Rust installation failed. Please check network connection or script output."
                continue
            fi

            echo "Updating environment variables..."
            source "$HOME/.cargo/env"

            if ! command -v cargo &> /dev/null; then
                echo "Cargo not found. Please manually add the Rust installation path to PATH."
                echo 'You can add the following line to ~/.bashrc or ~/.zshrc to resolve this:'
                echo 'export PATH="$HOME/.cargo/bin:$PATH"'
                continue
            fi

            echo "Verifying Rust and Cargo installation..."
            rustc --version
            cargo --version
            echo "Rust and Cargo have been successfully installed!"

            # Prompt for wallet address and validate input
            while true; do
                read -rp "Please enter your Shaicoin wallet address: " wallet_address
                if [[ ${#wallet_address} -eq 42 ]]; then
                    echo "Entered wallet address: $wallet_address"
                    break
                else
                    echo "Error: Invalid wallet address. Ensure it is 42 characters long."
                fi
            done

            # Remove /root/shaipot directory if it exists
            if [ -d "/root/shaipot" ]; then
                echo "Directory /root/shaipot already exists, removing..."
                rm -rf /root/shaipot
            fi

            # Clone the latest shaipot repository
            echo "Cloning shaipot repository..."
            git clone https://github.com/shaicoin/shaipot.git /root/shaipot

            # Enter project directory
            cd /root/shaipot
            echo "Current directory: $(pwd)"

            echo "Compiling shaipot mining program..."
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

            echo "Reloading systemd configuration and starting service..."
            systemctl daemon-reload
            systemctl start shai
            systemctl enable shai
            echo "Shaipot mining program has been started as a service and enabled."
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
            echo "Shaicoin mining service has been successfully restarted."
            ;;

        4)
            # Stop service
            echo "Stopping Shaicoin mining service..."
            systemctl stop shai
            echo "Shaicoin mining service has been successfully stopped."
            ;;

        5)
            # Enable service at startup
            echo "Enabling Shaicoin mining service at startup..."
            systemctl enable shai
            echo "Shaicoin mining service has been enabled at startup."
            ;;

        6)
            # Disable service at startup
            echo "Disabling Shaicoin mining service at startup..."
            systemctl disable shai
            echo "Shaicoin mining service has been disabled at startup."
            ;;

        *)
            echo "Invalid option. Please enter a number between 1 and 7."
            ;;
    esac

    echo -e "\n"
done
