sudo apt-get -y update

sudo apt-get -y install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg2 \
    software-properties-common

curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -

sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/debian \
   $(lsb_release -cs) \
   stable"

sudo apt-get -y update

sudo apt-get -y install docker-ce docker-ce-cli containerd.io

sudo usermod -a -G docker rael

sudo apt-get -y remove docker-compose
sudo curl -L "https://github.com/docker/compose/releases/download/1.23.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

curl https://www.mongodb.org/static/pgp/server-4.0.asc | sudo apt-key add -
echo "deb http://repo.mongodb.org/apt/debian stretch/mongodb-org/4.0 main" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.0.list
sudo apt-get -y update
sudo apt-get install -y mongodb-org-shell

sudo apt-get install -y golang

export GOPATH=$HOME/.go
go get github.com/jsha/minica
cp $HOME/.go/bin/minica /usr/local/bin