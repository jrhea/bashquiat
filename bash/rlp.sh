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

# doesn't pad with 0s
dec_to_bin() {
    local n bit
    for (( n=$1 ; n>0 ; n >>= 1 )); do  bit="$(( n&1 ))$bit"; done
    printf "%s" "$bit" 
}

rlp_encode_len() {
    local length=$1
    local offset=$(hex_to_dec $2)
    if [ $length -lt 56 ]
    then
        printf $(dec_to_hex $(($length + $offset)))
    elif [ $length -lt $((2**62)) ] # TODO: should be 2**64, but BASH doesn't like it
    then
        local length_binary=$(dec_to_bin $length)
        # Because dec_to_bin() doesn't pad with zeros we ensure that truncating arithmetic rounds 
        # up by adding (denom-1) to the numerator.
        local length_bytes=$(( (${#length_binary}+7)/8 ))
        # 128 (0x80) + 55 (0x37) = 183 (0xb7) + numBytes(string length)
        printf $(dec_to_hex $(( $offset + 55 + $length_bytes )))$(dec_to_hex $length)
    else
        exit 1
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
        printf $(rlp_encode_len $length 0x80)"$input"
    fi
    
}

#hex_to_dec 0x7F
#char_to_hex a
#rlp_encode_str a
#rlp_encode_str dog
rlp_encode_str "Lorem ipsum dolor sit amet, consectetur adipisicing elit"
#rlp_encode_len 3 0x80
#dec_to_bin 25633445434
