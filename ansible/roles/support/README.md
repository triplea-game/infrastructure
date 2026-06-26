Sets up support-server


## Key Configuration

**Important**: must have 'auto-configure networking' to be set on the linode.
This needs to be set in account settings to enable for new linodes,
otherwise needs to be set on the support server linode.

To debug, run `ip -4 addr` and check for a `192.*` IP address, if none
appears than the network helper is not running. Typically it would
run on boot-up.
