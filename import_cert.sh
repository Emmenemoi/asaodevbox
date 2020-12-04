#!/bin/sh
if [ -f "/asaodevbox" ]; then
  machine="Docker"
else
  unameOut="$(uname -s)"
  case "${unameOut}" in
      Linux*)     machine=Linux;;
      Darwin*)    machine=Mac;;
      CYGWIN*)    machine=Cygwin;;
      MINGW*)     machine=MinGw;;
      *)          machine="UNKNOWN:${unameOut}"
  esac
fi
echo ${machine}

# MacOS system keychain - import website certificate
# temporary file to store certificate
certificate_file=$(mktemp)
# delete temporary file on exit
trap "unlink $certificate_file" EXIT
# domain address (eg. example.org)
certificate_domain=${1:-asaodevbox.local}
# execute only if domain is provided
if [ ! -z "$certificate_domain" ]; then
  echo "domain address: $certificate_domain"
  # download remote certificate
  echo -n | openssl s_client -connect ${certificate_domain}:443 2>/dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > $certificate_file
  # get certificate size and status
  certificate_size=$(stat -f "%z" $certificate_file)
  certificate_status=$(openssl x509 -in $certificate_file -noout 2>/dev/null; echo $?)
  if [ "$certificate_size" -gt "0" ] && [ "$certificate_status" -eq "0" ]; then
    echo "certificate details: "
    openssl x509 -in $certificate_file -noout -text | awk "/X509v3 Subject Alternative Name/{getline;print}; /Subject:/ {print}" | tr -s "^ "
    # import certificate to system keychain
    if [ "$machine" == "Mac" ]; then
      # https://blog.container-solutions.com/adding-self-signed-registry-certs-docker-mac
      sudo security add-trusted-cert -d -r trustRoot -k "/Library/Keychains/System.keychain" $certificate_file
      # import inside the mac docker VM for trusted push
      #docker run -it --rm -v $certificate_file:/tmp/asaodevbox_cert.pem --privileged --pid=host justincormack/nsenter1 bash -c "mkdir -p /etc/docker/certs.d/registry.asaodevbox.local;cat /tmp/asaodevbox_cert.pem > /etc/docker/certs.d/registry.asaodevbox.local/ca.crt"
    elif [ "$machine" == "Linux" ]; then
      # Do something under GNU/Linux platform
      mkdir /etc/docker/certs.d/registry.${certificate_domain}
      cp $certificate_file /etc/docker/certs.d/registry.${certificate_domain}/
    elif [ "$machine" == "Docker" ]; then
      mkdir /etc/docker/certs.d/registry.${certificate_domain}
      cp $certificate_file /etc/docker/certs.d/registry.${certificate_domain}/
    fi
    if [ "$?" -eq "0" ]; then
      echo "certificate imported"
    else
      echo "certificate not imported"
      exit 2
    fi
  else
    echo "certificate not downloaded or bogus"
    exit 1
  fi
fi