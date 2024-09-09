#!/bin/bash

# Get the directory of the script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Source utility functions from utils.sh
source $DIR/utils.sh

# Function to encode the length in RLP format
rlp_encode_len() {
    local length=$1  # Length to encode
    local offset=$(hex_to_int "$2")  # Offset for encoding (either 0x80 for strings or 0xc0 for lists)
    if [ "$length" -lt 56 ]; then
        # For lengths < 56, encode as a single byte
        printf "$(int_to_hex $((length + offset)))"
    elif [ "$length" -lt $((2**63 - 1)) ]; then # TODO: this should be 2^64, but bash overflows at 2^63
        local length_binary length_bytes
        length_binary=$(int_to_bin "$length")

        # Because int_to_bin() doesn't pad with zeros we ensure that truncating arithmetic rounds 
        # up by adding (denom-1) to the numerator.
        length_bytes=$(( (${#length_binary}+7)/8 ))
        
        # 128 (0x80) + 55 (0x37) = 183 (0xb7) + numBytes(string length)
        # Encode the length of the length, followed by the length itself
        printf "$(int_to_hex $(( offset + 55 + length_bytes )))$(int_to_hex "$length")"
    else
        # Exit if length is too large
        exit 1
    fi
}

# Function to decode the length in RLP format
rlp_decode_length() {
    local input=$1
    local length=$(( (${#input}+1)/2 ))  # Calculate byte length of input
    local result
    if [ "$length" -eq 0 ]; then
        printf "input is null" >&2
        exit 1
    fi
    prefix=$((16#${input:0:2}))  # Get the first byte as integer
    if [ "$prefix" -le 127 ]; then #0x7f
        # Single byte item
        result=(0 2 "item")
    elif [ "$prefix" -le 183 ]; then #0xb7
        # Short string
        strLen=$(((prefix-128)*2))
        result=(2 "$strLen" "item")
    elif [ "$prefix" -le 191 ]; then
        # Long string
        lenOfStrLen=$(((prefix-183)*2))
        strLen=$((16#${input:2:$lenOfStrLen}*2)) # $((...)) converts to base 10 and mult by 2
        result=($((2+lenOfStrLen)) "$strLen" "item")
    elif [ "$prefix" -le 247 ]; then
        # Short list
        listLen=$((2*(prefix-192)))
        result=(2 "$listLen" list)
    else
        # Long list
        lenOfListLen=$(((prefix-247)*2))
        listLen=$((16#${input:2:$lenOfListLen}*2)) # $((...)) converts to base 10 and mult by 2
        result=($((2+lenOfListLen)) "$listLen" list)
    fi
    printf "${result[*]}"
}

# Function to encode a single item in RLP format
rlp_encode_item() {
    local input=$1
    local length=$2

    # Check if input is a number
    if [[ $input =~ ^[0-9]+$ ]]; then
        local input_hex
        if [ "$input" = "0" ]; then
            # Zero is encoded as 0x80
            printf "80"
        elif [ "$input" -lt 128 ] 2>/dev/null; then
            # Single byte numbers < 128 are encoded as-is
            printf "%s" "$(int_to_hex "$input")"
        else
            # Handle large integers as strings
            printf -v input_hex "%s" "$(printf "obase=16; %s\n" "$input" | bc)"

            # Ensure even number of characters
            [ $((${#input_hex} % 2)) -eq 1 ] && input_hex="0$input_hex"

            # Convert to lowercase
            input_hex=$(to_lower_hex "$input_hex")
            length=$((${#input_hex} / 2))
            printf "%s%s" "$(rlp_encode_len $length 80)" "$input_hex"
        fi
    # Otherwise input is a string
    else
        if [ "$length" -eq 0 ]; then
            # Empty string is encoded as 0x80
            printf "80"
        elif [ "$length" -eq 1 ] && [ "$(char_to_int "$input")" -lt 128 ]; then
            # Single character strings < 128 are encoded as-is
            printf "$(char_to_hex "$input")"
        else
            # Encode string length followed by the string itself
            printf "%s%s" "$(rlp_encode_len "$length" 80)" "$(str_to_hex "$input")"
        fi
    fi
}

# Function to decode a single item in RLP format
rlp_decode_item() {
    local input=$1
    local offset=$2
    local dataLen=$3

    if [ "$dataLen" -eq 0 ]; then
        printf ""
    else
        local value=$(hex_to_int "$input")
        local isNotPrintable=$(not_printable "$input")
        if [ "$value" -gt 0 ] && [ "$value" -lt 128 ]; then
            # Single byte values between 0 and 127 are decoded as-is
            printf "$value"
        elif [ "$isNotPrintable" -eq "0" ]; then 
            # Printable strings are decoded to ASCII
            hex_to_str "$input"
        elif [ "$value" -lt 0 ] || [ "$value" -lt $((2**63 - 1)) ]; then
            # Large integers are decoded using big integer conversion
            hex_to_big_int "$input"
        else
            # Other values are printed as-is
            printf "$value"
        fi
    fi
}

# Function to encode a list in RLP format
rlp_encode_list() {
    local input=$1
    local count=0
    local array=()

    # Search for a delimiter not surrounded in brackets
    for (( i=0; i<${#input}; i++ ));
    do
        if [ "${input:$i:1}" == "[" ]; then
            ((count=count + 1))
        elif [ "${input:$i:1}" == "]" ]; then
            ((count=count - 1))
        elif [ "${input:$i:1}" == "," ] && [ $count -eq 0 ]; then
            # replace the character in the ith position with a new delimiter that we can split on 
            input=$(printf "$input" | sed s/./\|/$((i + 1)))
        fi
    done

    # Add items to array
    IFS='|' read -r -a items <<< "$input"
    for item in "${items[@]}"; do
        array+=("$(rlp_encode "$item")")
    done

    # flatten array into result
    printf -v result '%s' "${array[@]}"

    # $(( (${#result}+1)/2 )) count bytes
    # Encode list length followed by the concatenated encoded items
    printf "$(rlp_encode_len $(( (${#result}+1)/2 )) c0)${result[*]}" 
}

# Function to decode a list in RLP format
rlp_decode_list() {
    local input="$1"
    local result="["
    local first=true

    while [ -n "$input" ]; do
        local offset dataLen type
        read -r offset dataLen type <<< "$(rlp_decode_length "$input")"
        if [ "$type" = "item" ]; then
            local item="${input:$offset:$dataLen}"
            if [ "$first" = true ]; then
                first=false
            else
                result+=","
            fi
            result+="$(rlp_decode_item "$item" 0 "$((dataLen/2))")"
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

# Main RLP encoding function
rlp_encode() {
    local input=$1
    local length=${#input}

    # Check if input is a list
    if [ "${input:0:1}" == "[" ] && [ "${input:$((length-1)):1}" == "]" ]; then
        rlp_encode_list "${input:1:$((length-2))}" # remove outer brackets
    else
        rlp_encode_item "$input" "$length"
    fi
}

# Main RLP decoding function
rlp_decode() {
    local input=$1
    local output offset dataLen type
    read -r offset dataLen type <<< "$(rlp_decode_length "${input}")"
    if [ "$type" = "item" ]; then
        output="${input:$offset:$dataLen}"
        printf '%s' "$(rlp_decode_item "$output" "$offset" "$((dataLen/2))")"
    elif [ "$type" = "list" ]; then
        output="${input:$offset:$dataLen}"
        printf '%s' "$(rlp_decode_list "$output")"
    fi
}