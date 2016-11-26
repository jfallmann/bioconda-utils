#!/bin/bash

set -eou pipefail

# This setup uses a unique ssh keypair where the private key has been encoded
# via travis encrypt-file.
#
# References:
#  - https://docs.travis-ci.com/user/encrypting-files/ and
#  - https://gist.github.com/domenic/ec8b0fc8ab45f39403dd


# to push to bioconda.github.io, use:
# BRANCH="master"
# ORIGIN="bioconda.github.io"
BRANCH="gh-pages"
ORIGIN="bioconda-utils"
GITHUB_USERNAME="bioconda"

SSH_REPO="git@github.com:${GITHUB_USERNAME}/${ORIGIN}.git"

SHA=$(git rev-parse --verify HEAD)
HERE=$(pwd)

# this is specific to how sphinx-quickstart was set up
DOCSOURCE=${HERE}/docs
DOCHTML=${HERE}/docs/build/html

ENCRYPTED_FILE=${HERE}/docs/key.enc
STAGING=/tmp/bioconda-docs

# clone the branch to tmpdir, clean out contents
rm -rf $STAGING
mkdir -p $STAGING
git clone $SSH_REPO $STAGING
cd $STAGING
git checkout $BRANCH || git checkout --orphan $BRANCH
rm -r *

# build docs and copy over to tmpdir
cd ${DOCSOURCE}
make html
cp -r ${DOCHTML}/* $STAGING


cd $STAGING
touch .nojekyll
git add .nojekyll
echo ".*" >> .gitignore
git add .


if [[
    $TRAVIS_BRANCH == "docs"
    && $TRAVIS_PULL_REQUEST == "false" 
]];then
    ENCRYPTED_KEY_VAR="encrypted_${ENCRYPTION_LABEL}_key"
    ENCRYPTED_IV_VAR="encrypted_${ENCRYPTION_LABEL}_iv"
    ENCRYPTED_KEY=${!ENCRYPTED_KEY_VAR}
    ENCRYPTED_IV=${!ENCRYPTED_IV_VAR}
    openssl aes-256-cbc -K $ENCRYPTED_KEY -iv $ENCRYPTED_IC -in $ENCRYPTED_FILE -out key
    chmod 600 key
    eval `ssh-agent -s`
    ssh-add key
    git config user.name "Travis CI"
    git config user.email " bioconda@users.noreply.github.com"
    git commit --all -m "Updated docs to commit ${SHA}."
    git push $SSH_REPO $BRANCH &> /dev/null
fi