#!/bin/bash

if [ -z "$RPC_URL" ]; then
    echo -e "\033[31mError:\033[0m Environment not initialized. Please run 00_init.sh first."
    return 1
fi

echo "Deploying GroupChat contract..."

forge_script ../DeployGroupChat.s.sol:DeployGroupChat --sig "run()"

if [ $? -eq 0 ]; then
    source $network_dir/address.group.chat.params
    echo -e "\033[32m✓\033[0m GroupChat deployed at: $groupChatAddress"
    return 0
else
    echo -e "\033[31m✗\033[0m Failed to deploy GroupChat"
    return 1
fi
