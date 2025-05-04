Installs a very barebones NGINX.


## Generating dhparam.pem 

Done by hand, one-time:

```
openssl dhparam -out /etc/nginx/dhparam.pem 4096
```
