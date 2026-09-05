Sets up the forums that runs as a nodebb server via docker compose.
TODO: Overall, we are missing 'nginx' configuration.

## Kernel constraint (MongoDB)

The `mongodb` container refuses to start on Linux kernels in the range
**6.19 – 7.0.13** (TCMalloc/rseq ABI incompatibility, MongoDB SERVER-121912).
On 2026-09-05 a Linode kernel roll pushed the forums box to `7.1.9-linode176`
and mongo `8.0.21` crash-looped, taking forums down.

The forums Linode is **not** managed by Terraform (`servers.auto.tfvars` marks it
`destroy = true`, pre-existing), so its kernel is set only in the Linode Manager.
Keep it on **GRUB 2** so it boots the distro kernel from `/boot` (currently the
6.8.x line, below 6.19). If you ever move it to a Linode-supplied kernel ≥6.19,
the mongo image must be **≥ 8.0.30** (or 8.3.9+/9.0+), the first releases that
re-allow startup on kernels ≥7.0.14/≥7.1.0. Until 8.0.30 ships, GRUB 2 + the
distro kernel is the supported combination.
