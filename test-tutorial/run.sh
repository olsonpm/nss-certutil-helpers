#! /usr/bin/env sh

# step 1
mkdir mutual-ssl
cd mutual-ssl

# step 2
mkdir nss node curl
cd nss

# step 3
nch create-db --directory root
nch create-db --directory server
nch create-db --directory client

# step 4
cd root
nch create-cert --common-name 'test-root-cn' \
  --nickname 'test-root-nick' \
  --signed-by 'self'

# step 5
nch export-cert --nickname 'test-root-nick' --cert-only

# step 6
cd ../server
nch import-cert --nickname 'test-root-nick' \
  --filepath ../root/test-root-nick.crt.pem \
  --is-root

# step 7
nch create-csr --common-name 'localhost' > test-server-nick.csr
cd ../client
nch create-csr --common-name 'test-client-cn' > test-client-nick.csr

# step 8
cd ../root
nch sign-csr --ca-nickname 'test-root-nick' \
  --csr-filepath ../server/test-server-nick.csr \
  > ../server/test-server-nick.crt
nch sign-csr --ca-nickname 'test-root-nick' \
  --csr-filepath ../client/test-client-nick.csr \
  > ../client/test-client-nick.crt

# step 9
cd ../server
nch import-cert --filepath test-server-nick.crt \
  --nickname 'test-server-nick'
cd ../client
nch import-cert --filepath test-client-nick.crt \
  --nickname 'test-client-nick'

# step 10
cd ../server
nch export-cert --nickname 'test-server-nick' \
  --filepath ../../node/test-server-nick.p12 \
  --format 'p12'
cd ../root
nch export-cert --nickname 'test-root-nick' \
  --cert-only \
  --filepath ../../curl/test-root-nick.crt.pem
cd ../client
nch export-cert --nickname 'test-client-nick' \
  --cert-only \
  --filepath ../../curl/test-client-nick.crt.pem
nch export-cert --nickname 'test-client-nick' \
  --key-only \
  --filepath ../../curl/test-client-nick.key.pem

# step 11
cd ../../node
wget https://raw.githubusercontent.com/olsonpm/nss-certutil-helpers/master/resources/node/package.json
wget https://raw.githubusercontent.com/olsonpm/nss-certutil-helpers/master/resources/node/server.js
npm install
echo -e "\n\nready for 'node server' and curl script\n\n"
