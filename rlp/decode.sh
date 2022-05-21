#!/bin/bash

hex_to_char() {
    printf "\x${1}"
}

hex_to_str(){
    for ((i=0;i<${#1};i+=2));do printf "$(hex_to_char "${1:$i:2}")";done
}

hex_to_int() {
    length=$(( (${#1}+1)/2 ))
    if [[ $length == 0 ]]; then
        echo "input is null" >&2
        exit 1
    elif [[ $length == 1 ]]; then
        printf "%d" "$((16#${1:0:2}))"
    else
        printf "%d" "'${1: -2}" + $(hex_to_int "${1:0:-2}") * 256
    fi
}

decode_length() {
    local input=$1
    local length=$(( (${#input}+1)/2 ))
    local result
    if [ "$length" -eq 0 ]; then
        printf "input is null" >&2
        exit 1
    fi
    prefix=$(printf "%d" "$((16#${input:0:2}))")
    if [ "$prefix" -le 127 ]; then
        result=(0 2 str)
    elif [ "$prefix" -le 183 ] && [ "$length" -gt $((prefix-128)) ]; then
        strLen=$(((prefix-128)*2))
        result=(2 "$strLen" str)
    elif [ "$prefix" -le 191 ] && [ "$length" -gt $((prefix-183)) ] && [ "$length" -gt $((prefix-183+${input:1:$((prefix-183))})) ]; then
        lenOfStrLen=$((prefix-183))
        strLen=${input:1:$lenOfStrLen}
        result=($((1+"$lenOfStrLen")) "$strLen" str)
    elif [ "$prefix" -le 247 ] && [ "$length" -gt $((prefix-192)) ]; then
        listLen=$((prefix-192))
        result=(1 "$listLen" list)
    elif [ "$prefix" -le 255 ] && [ "$length" -gt $((prefix-247)) ] && [ "$length" -gt $((prefix-247+${input:1:$((prefix-247))})) ]; then
        lenOfListLen=$((prefix-247))
        listLen=${input:1:$lenOfListLen}
        result=($((1+"$lenOfListLen")) "$listLen" list)
    else
        printf "input don't conform RLP encoding form" >&2
        exit 1
    fi
    printf "${result[*]}"
}

rlp_decode() {
    input=$1
    if [ "${#input}" -eq 0 ]; then
        return
    fi
    output=""
    IFS=' ' read -r -a arr <<< $(decode_length "${input}")

    offset=${arr[0]}
    dataLen=${arr[1]}
    type=${arr[2]}
    if [ "$type" == "str" ]; then
        output=$(printf "${input:$offset:(($dataLen))}")
    fi
    printf "$(hex_to_str $output)"
}

#decode_length 83646f67
#hex_to_char 64
#hex_to_int 83
rlp_decode 83646f67
