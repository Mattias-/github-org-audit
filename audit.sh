#!/bin/bash

check_user_keys() {
    user=$1
    echo "Checking keys for $user"
    hub api "https://api.github.com/users/$user/keys" |
        jq -r '.[].key' |
        while read -r key; do
            rkey=$(ssh-keygen -l -f - <<<"$key")
            key_len=$(echo "$rkey" | cut -d' ' -f1)
            key_type=$(echo "$rkey" | cut -d' ' -f5)

            # RSA keys must be over 2048 bits
            if (("$key_len" <= 2048)) && [ "$key_type" == "(RSA)" ]; then
                echo "$user" "$key_len" "$key_type"
            fi
        done
}

main() {
    users=$(hub api "https://api.github.com/orgs/$ORG/members?per_page=100" |
        jq -r '.[].login')

    pids=()
    for user in $users; do
        check_user_keys "$user" &
        pids+=($!)
    done
    for pid in "${pids[@]}"; do
        wait "$pid" || echo "failed job PID=$pid"
    done
}

if ! hub --version &>/dev/null; then
    echo "Please install hub"
    exit 1
fi
if ! hub api "https://api.github.com/user" &>/dev/null; then
    echo "Please set up Github access for hub"
    exit 1
fi
if ! jq --version &>/dev/null; then
    echo "Please install jq"
    exit 1
fi
if [ -z "$ORG" ]; then
    echo "Please set the ORG environment variable"
    echo "ORG=xxx $0"
    exit 1
fi

main
