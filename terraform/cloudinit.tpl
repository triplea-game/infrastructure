#cloud-config
# 'cloud-config' file that creates user accounts on first boot
users:
%{ for admin in admins ~}
  - name: ${admin.name}
    sudo:
      - ALL=(ALL) NOPASSWD:ALL
      - Defaults:${admin.name} !requiretty
    shell: /bin/bash
    ssh_authorized_keys:
%{ for key in admin.ssh_keys ~}
      - ${key}
%{ endfor ~}

%{ endfor ~}
ssh_pwauth: false
