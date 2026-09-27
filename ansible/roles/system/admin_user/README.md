Creates the 'admin' user on each host and deploys SSH keys. Admin user is a maintenance user
for the TripleA team to be able to ssh into the server. Admin user has sudo access.

Names listed in `removed_admins` (`group_vars/all.yml`) are revoked: their sudoers file and
account are deleted, the home directory is kept. A name in both lists fails the run.
