#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $DIR/../enr.sh

test_enr(){
    local seq="1"
    local public_key="03ca634cae0d49acb401d8a4c6b6fe8c55b70d115bf400769cc1400f3258cd3138"
    local private_key="b71c71a67e1177ad4e901695e1b4b9ee17ae16c6668d313eac2f96dbcda3f291"
    local ip="127.0.0.1"
    local udp=30303

    local encoded=$(encode_enr "$seq" "$public_key" "$private_key" "$ip" "$udp")
    printf "%s\n" "$encoded"
}


test_enr
