#!/bin/bash

to_upper_hex() {
    printf '%s' "$1" | sed 'y/abcdef/ABCDEF/'
}

to_lower_hex() {
    printf '%s' "$1" | sed 'y/ABCDEF/abcdef/'
}

remove_leading_zeros() {
    local hex="$1"
    # Remove leading zeros, but keep at least one digit
    while [[ "${hex:0:1}" == "0" && ${#hex} -gt 1 ]]; do
        hex="${hex:1}"
    done
    printf '%s' "$hex"
}

char_to_hex() {
    printf  "%02x" "'${1}"
}

hex_to_char() {
    printf "\x${1}"
}

char_to_int() {
    printf  "%d" "'${1}"
}

str_to_hex() {
    for ((i=0;i<${#1};i++));do 
        printf "$(char_to_hex "${1:$i:1}")";
    done
}

hex_to_str() {
    local hex="$1"
    local str=""
    local i

    for ((i = 0; i < ${#hex}; i += 2)); do
        str+=$(hex_to_char "${hex:i:2}")
    done

    printf "%s" "$str"
}

# doesn't pad with 0s
int_to_bin() {
    local n bit
    for (( n=$1 ; n>0 ; n >>= 1 )); do  bit="$(( n&1 ))$bit"; done
    printf "%s" "$bit" 
}

int_to_hex() {
    printf -v num "%x" "$1"
    if [ "$(( (${#num}+1)/2 ))" -eq "$(( (${#num})/2 ))" ]; then
        printf "$num"
    else
        printf 0"$num"
    fi
}

hex_to_int() {
    printf "%d" "$((16#$1))"
}

hex_to_big_int() {
    local hex=$1
    local dec

    # Remove leading zeros
    hex=$(remove_leading_zeros "$hex")

    # If hex is empty after removing zeros, it was all zeros
    if [ -z "$hex" ]; then
        printf '0'
        return
    fi

    # Convert hex to uppercase
    hex=$(to_upper_hex "$hex")

    # Convert hex to decimal using bc
    # BC_LINE_LENGTH=0 is required to prevent bc from wrapping lines
    dec=$(printf 'ibase=16; %s\n' "$hex" | BC_LINE_LENGTH=0 bc)
    printf '%s' "$dec"
}

not_printable() {
    local hex="$1"
    local len=${#hex}
    for ((i=0; i<len; i+=2)); do
        local byte=$((16#${hex:i:2}))
        if ((byte < 32 || byte > 126)); then
            printf '1'
            return
        fi
    done
    printf '0'
}