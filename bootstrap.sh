echo "deb https://repo.saltproject.io/py3/debian/10/armhf/3003 buster main" > /etc/apt/sources.list.d/salt.list

wget https://repo.saltproject.io/py3/debian/10/armhf/3003/SALTSTACK-GPG-KEY.pub -O - | apt-key add -

apt update

apt install -yqq salt-minion
