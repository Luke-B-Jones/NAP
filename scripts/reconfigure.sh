#!/bin/bash
source config.sh
# Define update function
config_location="${w_d}/config.sh"
update_config() {
    local var_name=$1
    local new_value=$2
    if grep -q "^export ${var_name}=" "$config_location"; then
        sed -i "s|^export ${var_name}=.*|export ${var_name}=\"${new_value}\"|" "$config_location"
    else
        echo "${er}ERROR:${in} failed to update config for ${var_name} ${r}"
    fi
}