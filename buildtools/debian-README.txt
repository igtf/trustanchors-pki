==============================================================================
Experimental Debian and APT distribution for the IGTF Trust Anchors
==============================================================================

Welcome to the experimental Debian/APT distibution area of the IGTF trust
anchors. Although care has been taken to ensure that this distribution is
installable and complete, no guarantees are given, but you are invited to
report your issues through your local CA or info@eugridpma.org.   You may 
have to wait  for a  subsequent release  of the  Trust Anchor  release to
solve your issue, or may be asked to use a temporary repository.

Using the distribution
----------------------
1. Install the EUGridPMA PGP key for apt:
    wget -q -O - \
      https://dist.eugridpma.info/distribution/igtf/current/GPG-KEY-EUGridPMA-RPM-3 \
      | apt-key add -
 
2. Add the following line to your sources.list file for APT:

 #### IGTF Trust Anchor Distribution ####
 deb http://dist.eugridpma.info/distribution/igtf/current igtf accredited

3. Populate the cache and install the meta-package

    apt-get update

  followed by install one or more of the Profiles you want to accept

    apt-get install ca-policy-igtf-classic
    apt-get install ca-policy-igtf-mics
    apt-get install ca-policy-igtf-slcs
    apt-get install ca-policy-igtf-iota

