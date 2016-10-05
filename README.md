# NSS certutil helpers -> `nch`

## What is it?

Just a friendly, narrow-focused command line wrapper to the certutil tool with
the goal of easily creating mutual ssl authentication.


## Why create it?
Because existing documentation for both openssl and nss is not sufficient to get
anyone started who doesn't already understand the ssl process.  Also both the
openssl and certutil cli experiences are abysmal.


## How can it help me?
These helpers can serve as a starting point, as a reference, and as a utility
for personal ssl use.


## Before I get technical
Supporting documentation I found helpful is listed at the bottom, though a large
thanks is due to Firstyear whose blog post listed and explained the pieces
fairly well.  It was just missing an example pulling them all together.


## To install
Git clone, append <clone path>/bin to your $PATH, and source it

```sh
$ git clone git@github.com:olsonpm/nss-certutil-helpers.git
$ cd nss-certutil-helpers/bin

# I'm assuming zsh, but you should append the following to whatever <shell>rc
#   file is applicable.
$ printf "\n# adds nss-certutil-helpers (nch) to your path" >> ~/.zshrc
$ printf "\nexport PATH=\${PATH}:$(pwd)\n" >> ~/.zshrc
$ . ~/.zshrc
```


## The functionality

This program should be self-exploratory.  Type `nch --help` to begin.

Understand a lot of the naming I used is specific to the context of this tool.
For instance I use the term 'root' when really 'ca' would be more general,
however since this tool only addresses a single-level hierarchy, 'root' is more
apt.

In short, `nch` provides the following
 - Create
   - The cert and key databases
   - A certificate
   - A CSR (Certificate signing request)

 - Sign, Export, and Import a certificate


## Tutorial
This goes through the process of setting up mutual ssl authentication between a
node server and curl script.  If you're not interested in node, then all but the
last few steps will still be relevant.  Each step should explain what to do, my
(admittedly unexperienced) understanding of why, and finally the
non-helper equivalent.

Please understand I'm very new to this, so let me know if anything can
be improved or if there are errors.

1) Create a directory 'mutual-ssl'.  This will be our project.
```sh
$ mkdir mutual-ssl && cd mutual-ssl
```

2) Create directories 'nss', 'node', and 'curl'.
 - `nss`: holds our nss databases for generating and interacting with our
certificates
 - `node`: holds our node server and its certificate
 - `curl`: holds the curl script (client) and its certificate
```sh
$ mkdir nss node curl && cd nss
```

3) Create empty databases in three different directories.
```sh
# root represents our self-signed, root CA
$ nch create-db --directory root

# server will hold the key and certificate chain for our node server
$ nch create-db --directory server

# client will hold the key and certificate chain for our curl script
$ nch create-db --directory client


# What happens under the hood (root example only)
$ mkdir root
$ certutil -N -d root --empty-password
```

4) Create a self-signed root certificate.  This will be used to sign our server
and client certificates
```sh
$ cd root
$ nch create-cert --common-name 'test-root-cn' \
  --nickname 'test-root-nick' \
  --signed-by 'self'


# Under the hood
$ certutil -S -n 'test-root-nick' -t 'C,C,C' -x -d . -s 'CN=test-root-cn'
```

5) Now let's export this certificate so we can import it into our server and
client databases
```sh
$ nch export-cert --nickname 'test-root-nick' --cert-only


# Under the hood
$ pk12util -o ./test-root-nick.p12 -d . -n 'test-root-nick' -W ''
$ openssl pkcs12 -in ./test-root-nick.p12 -out ./test-root-nick.crt.pem -nokeys -clcerts -password 'pass:'
$ rm ./test-root-nick.p12
$ chmod 400 ./test-root-nick.crt.pem
```

6) And import the cert.  By importing the root certificate into our server
database, we are able to export the certificate chain which is necessary for
client validation
```sh
$ cd ../server
$ nch import-cert --nickname 'test-root-nick' \
  --filepath ../root/test-root-nick.crt.pem \
  --is-root

# Under the hood
$ certutil -A -n 'test-root-nick' -t 'C,C,C' -i ../root/test-root-nick.crt -d .
```

7) Create a CSR for our client and server each.
```sh
$ cd ../server
$ nch create-csr --common-name 'localhost' > test-server-nick.csr

$ cd ../client
$ nch create-csr --common-name 'test-client-cn' > test-client-nick.csr


# Under the hood (server example only)
$ certutil -d . -R -s 'CN=localhost'
```

8) Sign the CSR using our root CA.  Since both our server and client will trust
the root CA, they can trust each other's signed certificates.
```sh
$ cd ../root

$ nch sign-csr --ca-nickname 'test-root-nick' \
  --csr-filepath ../server/test-server-nick.csr \
  > ../server/test-server-nick.crt

$ nch sign-csr --ca-nickname 'test-root-nick' \
  --csr-filepath ../client/test-client-nick.csr \
  > ../client/test-client-nick.crt


# Under the hood (server example only)
$ certutil -C -d . -i ../server/test-server-nick.csr -c 'test-root-nick'
```

9) Import the signed certificate.  This will complete our server and client
databases, meaning they will each have a private key, a signed public
certificate, and the chain of certificates leading up to the self-signed
trusted CA (in our case, the 'chain' is just the root -> client/server)
```sh
$ cd ../server
$ nch import-cert --filepath test-server-nick.crt \
  --nickname 'test-server-nick'

$ cd ../client
$ nch import-cert --filepath test-client-nick.crt \
  --nickname 'test-client-nick'

# Under the hood (server example only)
$ certutil -A -n 'test-server-nick' -t ',,' -i test-client-nick.crt -d .
```

10) Export the data necessary for each our node server and curl script (client)
```sh
# The p12 file encompasses the certificate chain as well as the private key
$ cd ../server
$ nch export-cert --nickname 'test-server-nick' \
  --filepath ../../node/test-server-nick.p12 \
  --format 'p12'

#
# The curl script needs three things to perform a successful mutually
#   authenticated request
#
# 1) The root's certificate so you can trust the server's identity
# 2) The client's certificate (which is signed by the root CA) so the server
#    can verify the client's authenticity and encrypt the initial shared secret
# 3) The client's private key to decrypt the initial shared secret
#
$ cd ../root
$ nch export-cert --nickname 'test-root-nick' \
  --cert-only
  --filepath ../../curl/test-root-nick.crt.pem
$ cd ../client
$ nch export-cert --nickname 'test-client-nick' \
  --cert-only \
  --filepath ../../curl/test-client-nick.crt.pem
$ nch export-cert --nickname 'test-client-nick' \
  --key-only \
  --filepath ../../curl/test-client-nick.key.pem
```

11) You are now all set up to create the node server.  I have a minimal one
in the repo that you can copy-paste, just make sure you have node v6+ installed
```sh
cd ../server
wget https://rawgit.com/olsonpm/nss-certutil-helpers/master/resources/node/{package.json,server.js}

```

## Supporting documentation
p12 - https://www.ssl.com/how-to/create-a-pfx-p12-certificate-file-using-openssl/
certutil howto - http://firstyear.id.au/blog/html/2014/07/10/NSS-OpenSSL_Command_How_to:_The_complete_list..html
