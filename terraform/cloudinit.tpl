#cloud-config
users:
  - name: root
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
%{ for key in root_keys ~}
      - ${key}
%{ endfor ~}

  - name: ansible
    gecos: Ansible User
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
%{ for key in ansible_keys ~}
      - ${key}
%{ endfor ~}

ssh_pwauth: false
