function installAnsible() {
  read -p "Ansible not installed, would you like to install it now with apt? " -n 1 -r
  echo    # (optional) move to a new line
  if [[ $REPLY =~ ^[Yy]$ ]]
  then
    # Install steps from:
    # https://docs.ansible.com/ansible/latest/installation_guide/installation_distros.html
    sudo apt update
    sudo apt install software-properties-common
    sudo add-apt-repository --yes --update ppa:ansible/ansible
    sudo apt install --yes ansible
  else
    exit
  fi
}
