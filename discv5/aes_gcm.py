import sys
import argparse
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

def aesgcm_encrypt(
    key: bytes, nonce: bytes, plain_text: bytes, associated_data: bytes,
) -> bytes:
    aesgcm = AESGCM(key)
    cipher_text = aesgcm.encrypt(nonce, plain_text, associated_data)
    return cipher_text

def aesgcm_decrypt(
    key: bytes, nonce: bytes, cipher_text: bytes, associated_data: bytes,
) -> bytes:
    aesgcm = AESGCM(key)
    plain_text = aesgcm.decrypt(nonce, cipher_text, associated_data)
    return plain_text

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='AES-GCM Encryption/Decryption')
    parser.add_argument('action', choices=['encrypt', 'decrypt'], help='Action to perform')
    parser.add_argument('key', help='Encryption key (hex)')
    parser.add_argument('nonce', help='Nonce (hex)')
    parser.add_argument('text', help='Plaintext or ciphertext (hex)')
    parser.add_argument('associated_data', help='Associated data (hex)')
    args = parser.parse_args()

    key = bytes.fromhex(args.key)
    nonce = bytes.fromhex(args.nonce)
    text = bytes.fromhex(args.text)
    associated_data = bytes.fromhex(args.associated_data)

    if args.action == 'encrypt':
        ciphertext = aesgcm_encrypt(key, nonce, text, associated_data)
        print(ciphertext.hex())
    else:
        plaintext = aesgcm_decrypt(key, nonce, text, associated_data)
        print(plaintext.hex())