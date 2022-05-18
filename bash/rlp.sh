#!/bin/bash

char_to_hex() {
    printf  "0x%x" "'${1}"
}

str_to_hex() {
    for ((i=0;i<${#1};i++));do printf $(char_to_hex ${1:$i:1});done
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
    local length=$2
    if [ $length -eq 1 ] && [ $(hex_to_dec $(char_to_hex "$input")) -lt $(hex_to_dec 0x80) ]
    then
        printf $(char_to_hex "$input")
    else
        printf $(rlp_encode_len $length 0x80)$(str_to_hex "$input")
    fi
}

rlp_encode_list() {
    printf list
}

rlp_encode() {
    local input=$1
    local length=${#input}
    if [ ${input:0:1} == "[" ] && [ ${input:$(($length-1)):$length} == "]" ]
    then
        rlp_encode_list $input
    else
        rlp_encode_str "$input" $length
    fi
}



#hex_to_dec 0x7F
#char_to_hex a
#str_to_hex dog
#rlp_encode_len 3 0x80
#dec_to_bin 25633445434

#rlp_encode a
rlp_encode dog
#rlp_encode "Lorem ipsum dolor sit amet, consectetur adipisicing elit"
#rlp_encode ['hello','world']


