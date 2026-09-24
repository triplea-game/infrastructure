#!/usr/bin/env bash
#
# forensic-check.sh — one-shot READ-ONLY forensic snapshot of a TripleA fleet host.
# Changes nothing: only reads logs, config, timers, docker state, and file mtimes.
#
#   ssh dan@<host-ip> 'sudo bash -s -- 30' < forensic-check.sh &> host-forensic.txt
#   (arg = days to look back; default 30)
#
# Built to answer "how did prod come to differ from main?" Most useful sections:
#   §3 nginx error-log timeline (when did a bad upstream start?)
#   §9 recently-changed /etc (which config file changed, exactly when)
#   §4/§5/§6 logins (was there an admin-account = manual apply near that time?)
# See docs/runbooks/troubleshooting-infrastructure.md.

DAYS="${1:-30}"
SINCE="-${DAYS}d"
sec() { printf '\n\n############################## %s\n' "$1"; }
run() { printf '\n$ %s\n' "$*"; "$@" 2>&1 | sed 's/^/    /'; }

echo "======================================================================"
echo " FORENSIC SNAPSHOT  host=$(hostname)  at=$(date -u +%FT%TZ)  window=${DAYS}d"
echo "======================================================================"

sec "0. HOST / CLOCK / UPTIME"
run date -u
run timedatectl
run uptime
printf '    boot: %s\n' "$(uptime -s 2>/dev/null)"

sec "1. REBOOT / BOOT HISTORY (did a reboot reload stale state?)"
run journalctl --list-boots --no-pager
run last -x -n 30 reboot shutdown

sec "2. JOURNAL COVERAGE (how far back can we see?)"
printf '    oldest: %s\n' "$(journalctl -o short-iso --no-pager 2>/dev/null | head -1)"
printf '    latest: %s\n' "$(journalctl -o short-iso --no-pager -n1 2>/dev/null)"

sec "3. NGINX ERROR-LOG TIMELINE  <== when did an upstream failure start/stop?"
for f in /var/log/nginx/error.log /var/log/nginx/error.log.1; do
  [ -f "$f" ] || continue
  echo "  --- $f : FIRST support/443/upstream errors ---"
  grep -nE 'support_backend|:443|no live upstream|while connecting to upstream' "$f" 2>/dev/null | head -4 | sed 's/^/    /'
  echo "  --- $f : LAST such errors ---"
  grep -nE 'support_backend|:443|no live upstream|while connecting to upstream' "$f" 2>/dev/null | tail -4 | sed 's/^/    /'
done
echo "  --- rotated error logs (earliest 443 mentions) ---"
zcat -f /var/log/nginx/error.log.*.gz 2>/dev/null | grep -E 'support_backend|:443' | head -4 | sed 's/^/    /'

sec "4. ALL ACCEPTED SSH LOGINS (raw: time . method . user . source IP)"
journalctl _COMM=sshd --since "$SINCE" -o short-iso --no-pager 2>/dev/null \
  | grep -E 'Accepted ' | sed 's/^/    /' || echo "    (none)"

sec "5. LOGIN SUMMARY by USER  (admin accounts here = manual/interactive)"
journalctl _COMM=sshd --since "$SINCE" --no-pager 2>/dev/null \
  | grep -oE 'Accepted \w+ for \S+' | awk '{print $4}' | sort | uniq -c | sort -rn | sed 's/^/    /'

sec "6. LOGIN SUMMARY by SOURCE IP  (Azure = CI; anything else = investigate)"
journalctl _COMM=sshd --since "$SINCE" --no-pager 2>/dev/null \
  | grep -E 'Accepted ' | grep -oE 'from [0-9a-fA-F.:]+' | awk '{print $2}' \
  | sort | uniq -c | sort -rn | sed 's/^/    /'

sec "7. FAILED / INVALID LOGINS (intrusion sanity check) — top 20 IPs"
journalctl _COMM=sshd --since "$SINCE" --no-pager 2>/dev/null \
  | grep -iE 'Failed password|Invalid user|authentication failure' \
  | grep -oE 'from [0-9a-fA-F.:]+' | awk '{print $2}' | sort | uniq -c | sort -rn | head -20 | sed 's/^/    /'

sec "8. SUDO COMMAND HISTORY (who ran what as root — last 100)"
journalctl _COMM=sudo --since "$SINCE" -o short-iso --no-pager 2>/dev/null \
  | grep -E 'COMMAND=' | tail -100 | sed 's/^/    /' || echo "    (none)"

sec "9. RECENTLY MODIFIED FILES in /etc (last ${DAYS}d) — what changed & exactly when"
find /etc -type f -mtime -"${DAYS}" -printf '%TY-%Tm-%Td %TH:%TM  %p\n' 2>/dev/null | sort | sed 's/^/    /'

sec "10. RECENTLY MODIFIED FILES in /opt and home dirs (last ${DAYS}d)"
find /opt /home 2>/dev/null -type f -mtime -"${DAYS}" -printf '%TY-%Tm-%Td %TH:%TM  %p\n' 2>/dev/null | sort | sed 's/^/    /'

sec "11. NGINX CONFIG FILES + MTIMES + support refs"
run ls -la --time-style=full-iso /etc/nginx/
for d in include conf.d sites-enabled sites-available; do
  [ -d "/etc/nginx/$d" ] && run ls -la --time-style=full-iso "/etc/nginx/$d/"
done
run grep -rniE "support_backend|:443|proxy_pass +https|:8010" /etc/nginx/

sec "12. NGINX EFFECTIVE CONFIG (nginx -T) — the actual resolved active config"
run nginx -T

sec "13. COMPOSE + ENV FILES: mtimes + port bindings"
for f in /opt/support/docker-compose.yml /opt/lobby/docker-compose.yml /opt/oauth2-proxy/docker-compose.yml; do
  [ -f "$f" ] || continue
  echo "  --- $f ---"; stat -c '    mtime=%y' "$f"
  grep -nE 'ports:|8010|443|127\.0\.0\.1|192\.168|image:' "$f" 2>/dev/null | sed 's/^/      /'
done

sec "14. DOCKER CONTAINERS (state, ports, created, restarts, image)"
run docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.CreatedAt}}'
for c in $(docker ps -aq 2>/dev/null); do
  docker inspect -f '    {{.Name}} started={{.State.StartedAt}} restarts={{.RestartCount}} image={{.Config.Image}}' "$c" 2>/dev/null
done

sec "15. CRON JOBS (auto-run that could rewrite config)"
run ls -la /etc/cron.d/ /etc/cron.daily/ /etc/cron.hourly/ /etc/cron.weekly/
for u in root dan deploy ansible; do
  echo "  crontab -u $u:"; crontab -l -u "$u" 2>/dev/null | sed 's/^/    /' || echo "    (none)"
done

sec "16. SYSTEMD TIMERS (auto-run units)"
run systemctl list-timers --all --no-pager

sec "17. ENABLED / CUSTOM SYSTEMD UNITS"
run bash -c "ls -la --time-style=full-iso /etc/systemd/system/*.service 2>/dev/null"

sec "18. APT / UNATTENDED-UPGRADE HISTORY (last window)"
run tail -n 50 /var/log/apt/history.log
run bash -c "grep -h \"$(date +%Y)-\" /var/log/unattended-upgrades/unattended-upgrades.log* 2>/dev/null | tail -30"

sec "19. ON-BOX SHELL HISTORY (admin/service accounts) — any interactive commands?"
for h in /root/.bash_history /home/dan/.bash_history /home/deploy/.bash_history /home/ansible/.bash_history; do
  [ -f "$h" ] || continue
  echo "  --- $h  (mtime $(stat -c %y "$h" 2>/dev/null); last 30) ---"
  tail -n 30 "$h" 2>/dev/null | sed 's/^/    /'
done

sec "20. AUTHORIZED_KEYS for deploy/admin accounts (who/what can apply)"
for k in /home/ansible/.ssh/authorized_keys /home/deploy/.ssh/authorized_keys /root/.ssh/authorized_keys /home/dan/.ssh/authorized_keys; do
  [ -f "$k" ] || continue
  echo "  --- $k  (mtime $(stat -c %y "$k" 2>/dev/null)) ---"
  awk '{print "    "$1"  ..."substr($NF,length($NF)-24)}' "$k" 2>/dev/null
done

echo
echo "==================== END SNAPSHOT: $(hostname) ===================="
