# Install terraform
mkdir -p ${HOME}/.local/bin/
wget https://releases.hashicorp.com/terraform/1.12.1/terraform_1.12.1_linux_amd64.zip
unzip -o terraform_1.12.1_linux_amd64.zip
install -m 755 terraform ${HOME}/.local/bin/terraform
rm -v terraform terraform_1.12.1_linux_amd64.zip* LICENSE.txt
# Fetch kubernetes-talks repo
test -d kubernetes-talks && mv kubernetes-talks kubernetes-talks.backup-${RANDOM}
git clone --depth=1 https://github.com/raelga/kubernetes-talks.git
cd ${HOME}/kubernetes-talks/course/terraform/aws-academy-ec2-instance/
${HOME}/.local/bin/terraform init
${HOME}/.local/bin/terraform apply --auto-approve
echo "Waiting for instance startup..."
sleep 60
# Connect to the instance
echo "Connect to the instance using:"
echo
echo "$(terraform output -raw ssh_cmd)"
