#!/bin/bash

KEY_NAME=${1:?"key name is required as 1. parameter"}
EXISTING_KEY=$2
KEY_PATH=.
KEY=$KEY_PATH/$KEY_NAME

if [ -s "$KEY.pem" ] && [ -s "$KEY.pub" ] && [ -z "$EXISTING_KEY" ]; then
    echo Using existing key pair
else
    rm -rf $KEY*
    mkdir -p $KEY_PATH

    if [ -z "$EXISTING_KEY" ]; then
        echo No key pair exists and no private key arg was passed, generating new keys
        openssl genrsa -out $KEY.pem 1024
        chmod 700 $KEY.pem
        ssh-keygen -y -f $KEY.pem > $KEY.pub
	chmod 700 $KEY.pub
    else
        echo Using private key $EXISTING_KEY for key pair
        cp $EXISTING_KEY $KEY.pem
        chmod 700 $KEY.pem
        ssh-keygen -y -f $KEY.pem > $KEY.pub
	chmod 700 $KEY.pub
    fi
fi
