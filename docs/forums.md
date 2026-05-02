
## Upgrading NodeBB

- Change the nodebb version in: ansible/roles/forums/node-bb/Dockerfile
- Update the package.json in: ansible/roles/forums/node-bb/install/package.json
  - EG: https://github.com/NodeBB/NodeBB/blob/master/install/package.json
- Run a redeployment:
  - `cd ansible; make apply`
- SSH to the server and restart:
  - `sudo systemctl restart forums`


## Successful Startup

When checking the logs, the following indicates successful startup:
```
nodebb-1  | 2026-05-02T22:11:11.327Z [4567/100] - info: [api] Adding 5 route(s) to `api/v3/plugins`
nodebb-1  | 2026-05-02T22:11:11.337Z [4567/100] - info: [router] Routes added
nodebb-1  | 2026-05-02T22:11:11.467Z [4567/100] - info: 🎉 NodeBB Ready
nodebb-1  | 2026-05-02T22:11:11.469Z [4567/100] - info: 🤝 Setting 'trust proxy' to true
nodebb-1  | 2026-05-02T22:11:11.471Z [4567/100] - info: 📡 NodeBB is now listening on: 0.0.0.0:4567
nodebb-1  | 2026-05-02T22:11:11.471Z [4567/100] - info: 🔗 Canonical URL: https://forums.triplea-game.org
```

## Check logs

```
docker compose -f '/opt/triplea-forums/docker-compose.yml' logs nodebb
docker compose -f '/opt/triplea-forums/docker-compose.yml' logs mongodb
```

## Restart
```
sudo systemctl restart forums
```

