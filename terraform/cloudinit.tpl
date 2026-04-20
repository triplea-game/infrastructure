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

%{ for admin in admins ~}
  # ${admin.name}: personal admin account created at first boot so this
  # maintainer can SSH in immediately and run Ansible without needing the
  # ansible service account key. Ansible converges on top idempotently.
  - name: ${admin.name}
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
%{ for key in admin.ssh_keys ~}
      - ${key}
%{ endfor ~}

%{ endfor ~}
ssh_pwauth: false
