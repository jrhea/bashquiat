#!/bin/bash

char_to_hex() {
    printf  "0x%x" "'${1}"
}

dec_to_hex() {
    printf  "0x%x" $1
}

hex_to_dec() {
    printf  "%d" $1
}

dec_to_bin() {
    local n bit
    for (( n=$1 ; n>0 ; n >>= 1 )); do  bit="$(( n&1 ))$bit"; done
    printf "%s" "$bit" # TODO: should this pad with 0s?
}

rlp_encode_length() {
    local length=$1
    local offset=$(hex_to_dec $2)
    if [ $length -lt 56 ]
    then
        printf $(dec_to_hex $(($length + $offset)))
    elif [ $length -lt $((2**62)) ] # TODO: should be 2**64, but BASH doesn't like it
    then
        local binary_length=$(dec_to_bin $length)
        printf $(dec_to_hex $(( ${#binary_length} + $offset + 55 )))$binary_length
    fi
    
}

rlp_encode_str() {
    local input=$1
    local input_hex=$(char_to_hex $input)
    local length=${#input}
    if [ $length -eq 1 ] && [ $(hex_to_dec $input_hex) -lt $(hex_to_dec 0x80) ]
    then
        printf $input
    else
        printf $(rlp_encode_length $length 0x80)$input
    fi
    
}

#hex_to_dec 0x7F
#char_to_hex a
#rlp_encode_str a
#rlp_encode_str dog
rlp_encode_str Comedown.Getoffyourfuckingcross.Weneedthefuckingspacetonailthenextfoolmartyr.
#rlp_encode_length 3 0x80
#dec_to_bin 25633445434
