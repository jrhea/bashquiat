#!/bin/bash

char_to_hex() {
    printf  "%x" "'${1}"
}

str_to_hex() {
    for ((i=0;i<${#1};i++));do printf $(char_to_hex "${1:$i:1}");done
}

dec_to_hex() {
    printf  "%x" $1
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
        # TODO: There is a more efficient way to do this
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
        # True if $input is algebraically equal; otherwise, false.
        if [ "$input" -eq "$input" ] 2> /dev/null
        then
            printf 0$(dec_to_hex "$input")
        else
            printf $(char_to_hex "$input")
        fi
        
    else
        # True if $input is algebraically equal; otherwise, false.
        if [ "$input" -eq "$input" ] 2> /dev/null
        then
            printf $(rlp_encode_len $length 0x80)0$(dec_to_hex "$input")
        else
            printf $(rlp_encode_len $length 0x80)$(str_to_hex "$input")
        fi
    fi
}

rlp_encode_list() {
    local input=$1
    local count=0
    local array=()


    # Search for a delimiter not surrounded in brackets
    for (( i=0; i<${#input}; i++ ));
    do
        if [ "${input:$i:1}" == "[" ]
        then
            ((count=$count + 1))
        elif [ "${input:$i:1}" == "]" ]
        then
            ((count=$count - 1))
        elif [ "${input:$i:1}" == "," ] && [ $count -eq 0 ]
        then
            # replace the character in the ith position with a new delimiter that we can split on 
            input=$(printf $input | sed s/./\|/$((i + 1)))
        fi
    done

    IFS='|' read -r -a items <<< "$input"
    for item in "${items[@]}"; do
        array+=($(rlp_encode $item))
    done
    # flatten array into result
    printf -v result '%s' "${array[@]}" # TODO: not a fan of using the extra variable here
    # $(( (${#result}+1)/2 )) count bytes
    printf $(rlp_encode_len $(( (${#result}+1)/2 )) 0xc0)"${result[*]}"    
}

rlp_encode() {
    local input=$1
    local length=${#input}
    if [ "${input:0:1}" == "[" ] && [ "${input:$(($length-1)):1}" == "]" ]
    then
        # remove outer brackets
        rlp_encode_list "${input:1:$(($length-2))}"
    else
        rlp_encode_str "$input" $length
    fi
}



#hex_to_dec 0x7F
#char_to_hex " "
#str_to_hex " "
#rlp_encode_len 3 0x80
#dec_to_bin 25633445434

rlp_encode " "
printf '\n%s\n' "20"
rlp_encode a
printf '\n%s\n' "61"
rlp_encode dog
printf '\n%s\n' "83646f67"
rlp_encode "Lorem ipsum dolor sit amet, consectetur adipisicing elit"
printf '\n%s\n' "b8384c6f72656d20697073756d20646f6c6f722073697420616d65742c20636f6e7365637465747572206164697069736963696e6720656c6974"
rlp_encode 1
printf '\n%s\n' "01"
rlp_encode 1000
printf '\n%s\n' "8203e8"
rlp_encode []
printf '\n%s\n' "c0"
rlp_encode ["dog","god","cat"]
printf '\n%s\n' "cc83646f6783676f6483636174"
rlp_encode ["zw",[4],1]
printf '\n%s\n' "c6827a77c10401"
rlp_encode [[[],[]],[]]
printf '\n%s\n' "c4c2c0c0c0"
rlp_encode [[],[[]],[[],[[]]]]
printf '\n%s\n' "c7c0c1c0c3c0c1c0"




