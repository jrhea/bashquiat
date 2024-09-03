#!/bin/bash

hex_to_char() {
    printf "\x${1}"
}

hex_to_str() {
    printf "$1" | xxd -r -p
}

hex_to_int() {
    printf "%d" "$((16#$1))"
}

hex_to_big_int() {
    local hex=$1
    local dec

    # Remove leading zeros
    hex=$(printf '%s' "$hex" | sed 's/^0*//')

    # If hex is empty after removing zeros, it was all zeros
    if [ -z "$hex" ]; then
        printf '0'
        return
    fi

    # Convert hex to uppercase
    hex=$(printf '%s' "$hex" | tr '[:lower:]' '[:upper:]')

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

decode_length() {
    local input=$1
    local length=$(( (${#input}+1)/2 ))
    local result
    if [ "$length" -eq 0 ]; then
        printf "input is null" >&2
        exit 1
    fi
    prefix=$((16#${input:0:2}))
    if [ "$prefix" -le 127 ]; then #0x7f
        result=(0 2 str)
    elif [ "$prefix" -le 183 ]; then #0xb7
        strLen=$(((prefix-128)*2))
        result=(2 "$strLen" str)
    elif [ "$prefix" -le 191 ]; then
        lenOfStrLen=$(((prefix-183)*2))
        strLen=$((16#${input:2:$lenOfStrLen}*2)) # convert to base 10 and mult by 2
        result=($((2+lenOfStrLen)) "$strLen" str)
    elif [ "$prefix" -le 247 ]; then
        listLen=$((2*(prefix-192)))
        result=(2 "$listLen" list)
    else
        lenOfListLen=$(((prefix-247)*2))
        listLen=$((16#${input:2:$lenOfListLen}*2)) # convert to base 10 and mult by 2
        result=($((2+lenOfListLen)) "$listLen" list)
    fi
    printf "${result[*]}"
}

rlp_decode_string() {
    local input=$1
    local offset=$2
    local dataLen=$3

    if [ "$dataLen" -eq 0 ]; then
        printf ""
    else
        local value=$(hex_to_int "$input")
        local isNotPrintable=$(not_printable "$input")
        if [ "$value" -gt 0 ] && [ "$value" -lt 128 ]; then
            printf "$value"
        elif [ "$isNotPrintable" -eq "0" ]; then 
            hex_to_str "$input"
        elif [ "$value" -lt 0 ] || [ "$value" -lt $((2**63 - 1)) ]; then
            hex_to_big_int "$input"
        else
            printf "$value"
        fi
    fi
}

rlp_decode_list() {
    local input="$1"
    local result="["
    local first=true

    while [ -n "$input" ]; do
        local offset dataLen type
        read -r offset dataLen type <<< "$(decode_length "$input")"

        if [ "$type" = "str" ]; then
            local item="${input:$offset:$dataLen}"
            if [ "$first" = true ]; then
                first=false
            else
                result+=","
            fi
            result+="$(rlp_decode_string "$item" 0 "$((dataLen/2))")"
        elif [ "$type" = "list" ]; then
            local sublist="${input:$offset:$dataLen}"
            if [ "$first" = true ]; then
                first=false
            else
                result+=","
            fi
            result+="$(rlp_decode_list "$sublist")"
        fi

        input="${input:$((offset+dataLen))}"
    done

    result+="]"
    printf "$result"
}

rlp_decode() {
    local input=$1
    if [ "${#input}" -eq 0 ]; then
        return
    fi
    local output=""
    local offset dataLen type
    
    read -r offset dataLen type <<< "$(decode_length "${input}")"

    if [ "$type" = "str" ]; then
        output="${input:$offset:$dataLen}"
        printf '%s' "$(rlp_decode_string "$output" "$offset" "$((dataLen/2))")"
    elif [ "$type" = "list" ]; then
        output="${input:$offset:$dataLen}"
        printf '%s' "$(rlp_decode_list "$output")"
    fi
}