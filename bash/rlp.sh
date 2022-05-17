#!/bin/bash

char_to_hex() {
    printf  "0x%x" "'${1}"
}

hex_to_dec() {
    printf  "%d" "$1"
}

rlp_encode_str() {
    local input=$1
    local input_hex=$(char_to_hex $input)
    local length=${#input}
    if [ $length -eq 1 ] && [ $(hex_to_dec $input_hex) -lt $(hex_to_dec 0x80) ]
    then
        printf $length
    fi
    
}

#hex_to_dec 0x7F
#char_to_hex a
rlp_encode_str a
