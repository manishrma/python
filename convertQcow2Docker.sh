#!/bin/bash
#
# Author: manishrma@gmail.com
#
# Convert the qcow2 to docker Image

set -e

#### getvariables ####
function _get_variables() {
  #printf "external variables :- $@ \n"
  for variable in "$@"; do
    substring=(${variable//=/ })
    case "${substring[0]}" in
        url*)
          printf "Setting up URL ${substring[1]} \n"
          url=${substring[1]}
          qcow=${url##*/}
          ;;
        qcow*)
          printf "Setting up qcow ${substring[1]} \n"
          qcow=${substring[1]}
          ;;
        tar*)
          printf "Setting up tar file ${substring[1]} \n"
          tar=${substring[1]}
          qcowName=${tar%.tar.gz}
          qcow=${qcow}.qcow2
          ;;
        tag*)
          printf "Setting up tag file ${substring[1]} \n"
          tag=${substring[1]}
          ;;
        *)
          printf "Invalid option: ${substring} \n"
          ;;
    esac
  done

  ## Set all the variables
  curdir=`pwd`
  if [ -z ${qcowName} ]; then
    qcowName=${qcow%.*}
  fi
  mntdir=${curdir}/${qcowName}
  raw=${qcowName}.raw
  if [ -z $tar ]; then
    tar=${qcowName}.tar.gz
  fi
}

## parse the variables
#_get_variables "$@"

function clean {
  _get_variables "$@"
  ## Clean the binaries
  printf "## Cleaning up binaries \n"
  rm -rf ${raw} ${tar}
}

function clean:bins {
  _get_variables "$@"
  ## cleaning all bins
  printf "## Cleaning bins \n"
  rm -rf ${qcow}
}

function clean:umount {
  _get_variables "$@"
  ## umount dirs
  if [ -z $mntdir ]; then
    printf "Provide the qcow Name to umount the respt dir\n"
    return
  fi
  printf "## Umount dirs \n"
  sudo umount $mntdir
  sudo rm -rf $mntdir
  printf "## Umount successfully \n"
}

function clean:all {
  ## Clean all
  printf "##### Cleaning everything ##### \n"
  clean:umount && clean:bins
}

function precheck {
  ## Check all the pkgs exists
  pass
}

function _downloadImage {
  if [ -z $url ]; then
    printf "No $url available to download \n"
    exit 1
  fi
  printf "wget image : $url \n"
  sudo wget $url
  printf "file: $qcow \n"
}


function convert() {
  _get_variables "$@"
  if [ -z $url ] && [ -z $qcow ]; then
    printf "Either of variable url OR qcow is needed\n"
    printf "check help \n"
    exit 1
  fi
  if [ ! -z $url ]; then
    _downloadImage
  fi
  
  printf "QCow Name :- ${qcowName} \n"
  file ${qcow}
  sudo qemu-img convert -f qcow2 -O raw ${qcow} ${raw}
  printf "Qcow converted successfully \n"
  sudo fdisk -lu ${raw}

  printf "Creating mnt dir $mntdir \n"
  mkdir -p ${mntdir}

  # Need to check which partition to mount
  # parted -s image.raw unit b print

  # print the partition to mount
  parted -s ${raw} unit b print

  # Get the partition offset from the user
  read -p "Enter the start offset of partition to mount: " offset

  sudo mount -o loop,rw,offset=${offset} ${raw} ${mntdir}
  printf "Raw file  mounted successfully \n"

  cd ${mntdir}
  printf "### Generating tar file \n"
  sudo tar -czf ${curdir}/${tar} .
  printf " Tar file ${tar} generated successfully \n"
  cd -
  file ${curdir}/${tar}

}

function upload {
   ## Import file to docker
   # We can get the args to add message OR variables
   # --message "New image imported from tarball"
   # refer :- https://docs.docker.com/reference/cli/docker/image/import/
   # Can also apply the tags
   _get_variables "$@"
   if [ -z $tar ] && [ -z $tag ]; then
     printf "No tarfile or tag provided \n"
     exit 1
   fi
   file $tar
   shasum=$(cat $tar | sudo docker import - ${tag})
   substring=(${shasum//:/ })
   digest=${substring[1]}
   printf "Digest :- $digest \n"
   printf "Docker Import successful \n"
}

function help {
    ## Print the help of the functions
    printf "${0} <commands> [args]\n\nCommands:\n"
    compgen -A function | grep -v "^_" | grep -v ":" | grep -v "help"| cat -n
    printf "Extended help: %s help:extended" "${0}"
    printf "\nEach task has comments for general usage\n"
}
function help:extended {
    ## Print the help of the functions
    printf "%s <commands> [args]\n\nCommands:\n" "${0}"
    compgen -A function | grep -v "^_" | cat -n
    printf "\nExtended help:\n  Each task has comments for general usage\n"
}

TIMEFORMAT="Command completed in %3lR \n"
time ${@:-help}
