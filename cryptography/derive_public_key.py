#!/usr/bin/env python3

import sys
import binascii
from eth_keys import keys

def derive_public_key(private_key_hex):
    try:
        # Convert hex input to bytes
        private_key_bytes = binascii.unhexlify(private_key_hex)
        
        # Create a PrivateKey object
        private_key = keys.PrivateKey(private_key_bytes)
        
        # Get the public key
        public_key = private_key.public_key
        
        # Get the uncompressed public key
        uncompressed_public_key = public_key.to_bytes()
        
        # Get the compressed public key
        compressed_public_key = public_key.to_compressed_bytes()
        
        return {
            "uncompressed": uncompressed_public_key.hex(),
            "compressed": compressed_public_key.hex()
        }
    except binascii.Error:
        return "Error: Invalid hexadecimal in private key"
    except Exception as e:
        return f"Error: {str(e)}"

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python derive_public_key.py <private_key_hex>")
        sys.exit(1)
    
    private_key_hex = sys.argv[1]
    result = derive_public_key(private_key_hex)
    
    if isinstance(result, dict):
        print(f"Uncompressed Public Key: {result['uncompressed']}")
        print(f"Compressed Public Key: {result['compressed']}")
    else:
        print(result)