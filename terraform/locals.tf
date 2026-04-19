locals {
  # Keep support for multiple root keys (public SSH file may contain many keys).
  # Use trimspace to remove any surrounding whitespace/newlines reliably.
  raw_root_keys = trimspace(file(var.ssh_pub_file))
  root_keys     = [for k in split("\n", local.raw_root_keys) : trimspace(k) if length(trimspace(k)) > 0]

  # There should only ever be a single ansible key. Read it as a single
  # trimmed string to keep the code simpler and avoid unnecessary lists.
  ansible_key = trimspace(file(var.ansible_pub_file))
}
