# ecdsa_sign.py
import sys
import binascii
from eth_keys import keys

def ecdsa_sign(message_hash_hex, private_key_hex):
    # Convert hex inputs to bytes
    message_hash_bytes = binascii.unhexlify(message_hash_hex)
    private_key_bytes = binascii.unhexlify(private_key_hex)
    
    # Load the private key
    private_key = keys.PrivateKey(private_key_bytes)
    
    # Sign the message hash using deterministic ECDSA
    signature = private_key.sign_msg_hash(message_hash_bytes)
    
    # Get the signature as r || s (64 bytes)
    signature_bytes = signature.r.to_bytes(32, 'big') + signature.s.to_bytes(32, 'big')
    return signature_bytes.hex()

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: ecdsa_sign.py <message_hash_hex> <private_key_hex>", file=sys.stderr)
        sys.exit(1)
    
    message_hash_hex = sys.argv[1]
    private_key_hex = sys.argv[2]
    signature = ecdsa_sign(message_hash_hex, private_key_hex)
    print(signature)
