# NSS certutil helpers -> `nch`

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
## Table of Contents
- [Intro](#intro)
- [To install](#to-install)
- [The functionality](#the-functionality)
- [Tutorial](#tutorial)
- [External Links](#external-links)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Intro

### What is it?

Just a friendly, narrow-focused command line wrapper to `certutil` with the goal
of easily creating mutual ssl authentication<sup>[5](#referenced-documentation)</sup>.


### Why create it?
Because existing documentation for both openssl and nss is not sufficient to get
anyone started who doesn't already understand the ssl process.  Also both the
openssl and certutil cli experiences are abysmal.


### How can it help me?
These helpers can serve as a starting point, as a reference, and as a utility
for personal ssl use.


### Before I get technical
Supporting documentation I found helpful is listed at the bottom, though a large
thanks is due to Firstyear<sup>[1](#referenced-documentation)</sup> whose blog
post listed and explained the pieces fairly well.  It was just missing an
example pulling them all together.


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

A lot of the naming I used is specific to the context of this tool.
For instance I use the term 'root' when really 'ca' would be more general,
however since this tool only addresses a single-level hierarchy
<sup>[2](#referenced-documentation)</sup>, 'root' is more apt.

In short, `nch` provides the following
 - Create
   - The cert and key databases<sup>[3](#referenced-documentation)</sup>
   - A certificate
   - A CSR (Certificate signing request)<sup>[4](#referenced-documentation)</sup>

 - Sign, Export, and Import a certificate


## Tutorial
This goes through the process of setting up mutual ssl authentication between a
node server and curl script. If you're not interested in node, then all but the
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
 - `node`: holds our node server and its supporting certificates/keys
 - `curl`: holds the curl script (client) and its supporting certificates/keys
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

4) Create a self-signed root certificate<sup>[6](#referenced-documentation)</sup>.
This will be used to sign our server and client certificates.
```sh
$ cd root
$ nch create-cert --common-name 'test-root-cn' \
  --nickname 'test-root-nick' \
  --signed-by 'self'


# Under the hood
$ head -c 100 < /dev/urandom > ./randfile
$ certutil -S -z ./randfile -n 'test-root-nick' -t 'CT,CT,CT' -x -d 'sql:.' -s 'CN=test-root-cn' --keyUsage certSigning
$ rm ./randfile
```

5) Now let's export this certificate so we can import it into our server database.
```sh
$ nch export-cert --nickname 'test-root-nick' --cert-only


# Under the hood
$ oldUmask="$(umask)"
$ umask 277
$ pk12util -o ./test-root-nick.p12 -d 'sql:.' -n 'test-root-nick' -W ''
$ umask "${oldUmask}"
$ openssl pkcs12 -in ./test-root-nick.p12 -out ./test-root-nick.crt.pem -nokeys -clcerts -password 'pass:'
$ rm ./test-root-nick.p12
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
$ certutil -A -n 'test-root-nick' -t 'C,C,C' -i ../root/test-root-nick.crt -d 'sql:.'
```

7) Create a CSR for our client and server each.

\**Note the server has a common-name 'localhost'.  This is the domain our node
server will be serving, and ssl requires the common-name to match the domain.
There's no functional requirement for the root and client common-names besides
their being unique*

```sh
$ cd ../server
$ nch create-csr --common-name 'localhost' > test-server-nick.csr

$ cd ../client
$ nch create-csr --common-name 'test-client-cn' > test-client-nick.csr


# Under the hood (server example only)
$ head -c 100 < /dev/urandom > ./randfile
$ certutil -d 'sql:.' -R -s 'CN=localhost' -z ./randfile
$ rm ./randfile
```

8) Sign the CSR using our root CA<sup>[7](#referenced-documentation)</sup>.
Since both our server and client will trust the root CA, they can trust each
other's signed certificates.
```sh
$ cd ../root

$ nch sign-csr --ca-nickname 'test-root-nick' \
  --csr-filepath ../server/test-server-nick.csr \
  > ../server/test-server-nick.crt

$ nch sign-csr --ca-nickname 'test-root-nick' \
  --csr-filepath ../client/test-client-nick.csr \
  > ../client/test-client-nick.crt


# Under the hood (server example only)
$ certutil -C -d 'sql:.' -i ../server/test-server-nick.csr -c 'test-root-nick'
```

9) Import the signed certificate.  This will complete our server and client
databases, meaning they will each have a private key and a signed public
certificate.  The server will also have the chain of certificates leading up to
the self-signed trusted CA (in our case, the 'chain' is just the
root -> client/server)
```sh
$ cd ../server
$ nch import-cert --filepath test-server-nick.crt \
  --nickname 'test-server-nick'

$ cd ../client
$ nch import-cert --filepath test-client-nick.crt \
  --nickname 'test-client-nick'

# Under the hood (server example only)
$ certutil -A -n 'test-server-nick' -t ',,' -i test-server-nick.crt -d 'sql:.'
```

10) Export the data necessary for each our node server and curl script (client)
 - p12 format information<sup>[8](#referenced-documentation)</sup>

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
  --cert-only \
  --filepath ../../curl/test-root-nick.crt.pem
$ cd ../client
$ nch export-cert --nickname 'test-client-nick' \
  --cert-only \
  --filepath ../../curl/test-client-nick.crt.pem
$ nch export-cert --nickname 'test-client-nick' \
  --key-only \
  --filepath ../../curl/test-client-nick.key.pem

# Under the hood will be similar to step 5 which also exports a cert
```

11) You are now all set up to create the node server.  I have a minimal one
in the repo that you can copy-paste, just make sure you have node v6+ installed
```sh
cd ../../node
wget https://raw.githubusercontent.com/olsonpm/nss-certutil-helpers/master/resources/node/package.json
wget https://raw.githubusercontent.com/olsonpm/nss-certutil-helpers/master/resources/node/server.js
npm install
node server # will output "server listening on port 8xxx"
```

12) And finally the curl script
```sh
cd ../curl
# you can specify the --verbose option if you care about the details of
#  the communication
curl --cacert ./test-root-nick.crt.pem \
  --cert ./test-client-nick.crt.pem \
  --key ./test-client-nick.key.pem \
  https://localhost:<server port here>

# should output:
# can I get a "woo!" for mutual ssl authentication?
```

### You done breh

## External Links

### Referenced documentation
1. [certutil how-to](http://firstyear.id.au/blog/html/2014/07/10/NSS-OpenSSL_Command_How_to:_The_complete_list..html)
2. Single level hierarchy (as opposed to multi-level)
 - A single level hierarchy just means there doesn't exist intermediary
   certificate authorities.  This is considered bad practice, however for
   personal use is just fine.
 - [Why does a Certificate Authority (CA) issue certificates from an intermediate authority instead of the root authority?](https://stackoverflow.com/questions/26659333/why-does-a-certificate-authority-ca-issue-certificates-from-an-intermediate-au)
 - [Benefits of Multiple-Level Certification Hierarchies](https://technet.microsoft.com/en-us/library/cc962078.aspx)
3. [New sqlite key and cert databases](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Developer_Guide/che-nsslib.html)
 - [transition to sqlite db](https://wiki.mozilla.org/NSS_Shared_DB)
4. [Certificate Signing Request](https://en.wikipedia.org/wiki/Certificate_signing_request)
5. [Two way ssl clarification](http://stackoverflow.com/questions/10725572/two-way-ssl-clarification)
6. [Self signed certificate](https://en.wikipedia.org/wiki/Self-signed_certificate)
7. [What does it mean for a digital certificate to be signed](http://security.stackexchange.com/questions/16595/what-does-it-mean-for-a-digital-certificate-to-be-signed)
8. [A primer on p12/pfx file info](https://www.ssl.com/how-to/create-a-pfx-p12-certificate-file-using-openssl/)

### Other supporting links I found helpful
 - [How does ssl/tls work?](http://security.stackexchange.com/questions/20803/how-does-ssl-tls-work)
 - [How do the processes for digital certificates signatures and ssl work](http://security.stackexchange.com/questions/7421/how-do-the-processes-for-digital-certificates-signatures-and-ssl-work)
 - [official certutil documentation](https://developer.mozilla.org/en-US/docs/Mozilla/Projects/NSS/tools/NSS_Tools_certutil)
 - [Supporting redhat documentation on managing an nss certificate database](https://access.redhat.com/documentation/en-US/Red_Hat_Certificate_System/8.0/html/Admin_Guide/Managing_the_Certificate_Database.html)
