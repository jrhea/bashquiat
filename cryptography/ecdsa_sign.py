import argparse
import binascii
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature

# ecdsa_sign.py
import sys
import binascii
from cryptography.hazmat.primitives.asymmetric import ec, utils
from cryptography.hazmat.primitives import hashes

def ecdsa_sign(message_hash_hex, private_key_hex):
    # Convert hex inputs to bytes
    message_hash_bytes = binascii.unhexlify(message_hash_hex)
    private_key_bytes = binascii.unhexlify(private_key_hex)

    # Load the private key
    private_key_int = int.from_bytes(private_key_bytes, byteorder='big')
    private_key_obj = ec.derive_private_key(private_key_int, ec.SECP256K1())

    # Sign the message hash
    signature_der = private_key_obj.sign(
        message_hash_bytes,
        ec.ECDSA(utils.Prehashed(hashes.SHA256()))
    )

    # Convert DER signature to raw r || s format
    r, s = utils.decode_dss_signature(signature_der)
    r_bytes = r.to_bytes(32, byteorder='big')
    s_bytes = s.to_bytes(32, byteorder='big')
    signature_raw = r_bytes + s_bytes

    return signature_raw.hex()

if __name__ == '__main__':
    message_hash_hex = sys.argv[1]
    private_key_hex = sys.argv[2]
    signature = ecdsa_sign(message_hash_hex, private_key_hex)
    print(signature)
