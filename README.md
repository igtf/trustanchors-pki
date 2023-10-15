# Interoperable Global Trust Federation - PKIX distribution source (IGTF Trust Anchors)

This is the source (unfiltered) of the EUGridPMA build of the trust anchor 
distribution (in its PKIX rendering) for the Interoperable Global Trust
Federation IGTF. 

> ** WARNING **
> This distribution source itself MUST NOT (really, RFC2119 "MUST NOT"!) be 
> used as a trust anchor set, since the build process takes into account 
> the accredited status (in each trust anchor meta-data file), the structure 
> of the IGTF, as well as the current validity of the root and intermediate
> certificates, the CRL status, and the accreditation/peer review status.


The approved source of IGTF PKIX trust anchors is at:

* [IGTF Current Distribution (PKIX)](https://dl.igtf.net/distribution/current/)

as well as at several distribution sites of our major relying parties. 
Releases are usually done on the last Monday of the month, but only when 
the trust anchor distribution has materially been updated. 

## Official distributions are signed

All official IGTF releases are signed with the EUGridPMA GPG signing key.
There are two current GPG keys:
* [EUGridPMA Distribution Signing Key 3 <info@eugridpma.org>](https://pgp.surfnet.nl/pks/lookup?search=d12e922822be64d50146188bc32d99c83cdbbc71&fingerprint=on&op=index)
* [EUGridPMA Distribution Signing Key 4 <info@eugridpma.org>](https://pgp.surfnet.nl/pks/lookup?search=565f4528ead3f53727b5a2e9b055005676341f1a&fingerprint=on&op=index)

Current production releases are (still) signed with Key #3, a 1024-bit DSA
key. In future releases we will move to a new RSA-2048 GPG package signing
key. The new public key file, GPG-KEY-EUGridPMA-RPM-4, is distributed with
all current official releases. You can retrieve the new public key file from 
  https://dl.igtf.net/distribution/GPG-KEY-EUGridPMA-RPM-4

## Use in coordinated-deployment infrastructures

If you are part of a coordinated-deployment infrastructure (e.g. a national
or regional e-Infrastructure, EGI, OSG, PRACE-RI, NAREGI or others) you may
want to await their announcement before installing the release.  They could
include localised adaptations. For reference we include the links below:
* [EGI](https://edu.nl/envyq) (EGI service providers please follow doc HOWTO01)
* [wLCG](https://lcg-ca.web.cern.ch)
* [Open Science Grid](https://repo.opensciencegrid.org/cadist/)

Not all IGTF releases are necessarily accompanied by infrastructure-specific
releases. If changes in the IGTF distribution  do not materially impact  the
distribution of the relying party, no associated release may be done, nor is
there a reason to update such a distribution.

## Supplementary download locations

The download repository is also mirrored by the EUGridPMA at
https://dist.eugridpma.info/distribution/igtf/
and is also available from the Debian distribution system for its supported
version, e.g. https://packages.debian.org/stable/igtf-policy-classic
The Debian native version supports debconf selection, which does not come
by default with the IGTF distributed versions

## Building the distribution

1. Checkout or clone this repository
1. Install the dependendies: perl, perl-DateTime, ar, tar, gpg, rpmbuild, rpm-sign, createrepo_c
1. When desired, create or select your own PGP key, say with key id `12345678`
1. Check whether the `buildtools/VERSION` file has your desired content
1. Build the distribution!

```
cd buildtools/
./cabuild4.pl --version=AUTO -s -f -o ~/1.123-GPSK12345678 --mkdeb -K 12345678
rsync -e ssh -av --delete ~/1.123-GPSK* webuser@example.com:/var/www/html/myown-distribution/releases/
```

## License

[![CC BY-SA 4.0][cc-by-shield]][cc-by]

This work is licensed under a [Creative Commons Attribution 4.0 International License][cc-by].

[cc-by]: http://creativecommons.org/licenses/by/4.0/
[cc-by-shield]: https://img.shields.io/badge/License-CC%20BY--4.0-lightgrey.svg
