# ecdsa_verify.py
import sys
import binascii
from eth_keys import keys

def ecdsa_verify(message_hash_hex, signature_hex, public_key_hex):
    # Convert hex inputs to bytes
    message_hash_bytes = binascii.unhexlify(message_hash_hex)
    signature_bytes = binascii.unhexlify(signature_hex)
    public_key_bytes = binascii.unhexlify(public_key_hex)

    # Load the public key from compressed bytes
    public_key = keys.PublicKey.from_compressed_bytes(public_key_bytes)

    # Extract r and s from the signature
    r = int.from_bytes(signature_bytes[:32], byteorder='big')
    s = int.from_bytes(signature_bytes[32:], byteorder='big')

    # Reconstruct the signature object
    signature = keys.Signature(vrs=(0, r, s))

    # Verify the signature
    return public_key.verify_msg_hash(message_hash_bytes, signature)

if __name__ == '__main__':
    if len(sys.argv) != 4:
        print("Usage: ecdsa_verify.py <message_hash_hex> <signature_hex> <public_key_hex>", file=sys.stderr)
        sys.exit(1)

    message_hash_hex = sys.argv[1]
    signature_hex = sys.argv[2]
    public_key_hex = sys.argv[3]

    is_valid = ecdsa_verify(message_hash_hex, signature_hex, public_key_hex)
    print(is_valid)
