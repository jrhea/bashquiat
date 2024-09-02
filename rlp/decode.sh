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
    echo "$result"
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

# decode_length 83646f67
# hex_to_char 64
# hex_to_int 83
# hex_to_int 80 

#rlp_decode 8F102030405060708090A0B0C0D0E0F2

# rlp_decode 8180 # works
# rlp_decode 80 # works
# rlp_decode 4f #79 works
# rlp_decode 83646f67 #dog works
# rlp_decode 8203e8 #1000 works
# rlp_decode 830186a0 #100000 works
# rlp_decode 21 #33 works
# rlp_decode 15 #21 works
# rlp_decode 01 #1 works
# rlp_decode 7e #126 works
# rlp_decode 8180 128 works
# rlp_decode b74c6f72656d20697073756d20646f6c6f722073697420616d65742c20636f6e7365637465747572206164697069736963696e6720656c69 #works
# rlp_decode b8384c6f72656d20697073756d20646f6c6f722073697420616d65742c20636f6e7365637465747572206164697069736963696e6720656c6974 #works
# rlp_decode b904004c6f72656d20697073756d20646f6c6f722073697420616d65742c20636f6e73656374657475722061646970697363696e6720656c69742e20437572616269747572206d6175726973206d61676e612c20737573636970697420736564207665686963756c61206e6f6e2c20696163756c697320666175636962757320746f72746f722e2050726f696e20737573636970697420756c74726963696573206d616c6573756164612e204475697320746f72746f7220656c69742c2064696374756d2071756973207472697374697175652065752c20756c7472696365732061742072697375732e204d6f72626920612065737420696d70657264696574206d6920756c6c616d636f7270657220616c6971756574207375736369706974206e6563206c6f72656d2e2041656e65616e2071756973206c656f206d6f6c6c69732c2076756c70757461746520656c6974207661726975732c20636f6e73657175617420656e696d2e204e756c6c6120756c74726963657320747572706973206a7573746f2c20657420706f73756572652075726e6120636f6e7365637465747572206e65632e2050726f696e206e6f6e20636f6e76616c6c6973206d657475732e20446f6e65632074656d706f7220697073756d20696e206d617572697320636f6e67756520736f6c6c696369747564696e2e20566573746962756c756d20616e746520697073756d207072696d697320696e206661756369627573206f726369206c756374757320657420756c74726963657320706f737565726520637562696c69612043757261653b2053757370656e646973736520636f6e76616c6c69732073656d2076656c206d617373612066617563696275732c2065676574206c6163696e6961206c616375732074656d706f722e204e756c6c61207175697320756c747269636965732070757275732e2050726f696e20617563746f722072686f6e637573206e69626820636f6e64696d656e74756d206d6f6c6c69732e20416c697175616d20636f6e73657175617420656e696d206174206d65747573206c75637475732c206120656c656966656e6420707572757320656765737461732e20437572616269747572206174206e696268206d657475732e204e616d20626962656e64756d2c206e6571756520617420617563746f72207472697374697175652c206c6f72656d206c696265726f20616c697175657420617263752c206e6f6e20696e74657264756d2074656c6c7573206c65637475732073697420616d65742065726f732e20437261732072686f6e6375732c206d65747573206163206f726e617265206375727375732c20646f6c6f72206a7573746f20756c747269636573206d657475732c20617420756c6c616d636f7270657220766f6c7574706174 #works