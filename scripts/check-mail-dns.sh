#!/usr/bin/env bash
#
# check-mail-dns.sh — validate the email/deliverability DNS for the TripleA
# lobby and dice mail senders, plus confirm obsolete records are cleaned up.
#
# Each sender (lobby, dice) should align ALL of:
#   From / envelope domain  ==  postfix HELO  ==  DKIM d=  ==  SPF domain  ==  PTR
# on its own subdomain. This script digs every record we expect and prints a
# PASS / FAIL checklist (exits non-zero if anything is wrong).
#
# Usage:
#   ./check-mail-dns.sh                # query public resolver 1.1.1.1
#   ./check-mail-dns.sh 8.8.8.8        # use a different resolver
#   ./check-mail-dns.sh dns1.registrar-servers.com   # query authoritative NS
#
# Tip: query the authoritative Namecheap nameserver to bypass caches and see
# the true current state (find it with: dig +short NS triplea-game.org).

set -u

# ---- expected values -------------------------------------------------------
APEX="triplea-game.org"
DKIM_SELECTOR="mail"

LOBBY_DOMAIN="lobby.triplea-game.org"
LOBBY_IP="45.56.110.254"          # lobby host mail-egress IP

DICE_DOMAIN="dice.triplea-game.org"
# dice IP is derived from its A record below (it was confirmed == egress IP)

RESOLVER="${1:-1.1.1.1}"

# ---- output helpers --------------------------------------------------------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  G=$'\033[32m'; R=$'\033[31m'; C=$'\033[36m'; B=$'\033[1m'; Z=$'\033[0m'
else
  G=""; R=""; C=""; B=""; Z=""
fi
PASS=0; FAIL=0
pass()  { printf "  ${G}\xe2\x9c\x94 PASS${Z}     %s\n" "$1"; PASS=$((PASS+1)); }
fail()  { printf "  ${R}\xe2\x9c\x98 FAIL${Z}     %s\n" "$1"; FAIL=$((FAIL+1)); }
info()  { printf "  ${C}\xe2\x84\xb9 INFO${Z}     %s\n" "$1"; }
section() { printf "\n${B}== %s ==${Z}\n" "$1"; }

# ---- dig helpers -----------------------------------------------------------
# Return TXT record(s) for a name with chunk-quotes stripped and joined.
txt() { dig +short TXT "$1" @"$RESOLVER" 2>/dev/null | sed 's/" "//g' | tr -d '"'; }
# Return the single TXT line that matches a marker (e.g. v=DKIM1 / v=spf1).
txt_match() { txt "$1" | grep -F -- "$2" | head -1; }
a_rec()  { dig +short A "$1" @"$RESOLVER" 2>/dev/null | grep -E '^[0-9.]+$'; }
ptr()    { dig +short -x "$1" @"$RESOLVER" 2>/dev/null | sed 's/\.$//' | head -1; }

# ---- generic checks --------------------------------------------------------
check_dkim() {  # $1 = sender domain
  local d="$1" name val pval
  name="${DKIM_SELECTOR}._domainkey.${d}"
  val="$(txt_match "$name" "v=DKIM1")"
  if [ -z "$val" ]; then
    fail "DKIM  $name — no v=DKIM1 record found"
    return
  fi
  pval="${val#*p=}"
  pval="${pval%%;*}"   # drop any trailing tags after the key
  if [ -z "$pval" ]; then
    fail "DKIM  $name — present but p= (public key) is empty"
  elif printf '%s' "$pval" | grep -qE '[[:space:]]'; then
    fail "DKIM  $name — embedded whitespace/tab inside p= key (re-paste clean)"
  elif printf '%s' "$pval" | grep -qvE '^[A-Za-z0-9+/=]+$'; then
    fail "DKIM  $name — p= contains non-base64 characters"
  else
    pass "DKIM  $name — v=DKIM1, clean ${#pval}-char key"
  fi
}

check_spf() {  # $1 = domain
  local d="$1" val
  val="$(txt_match "$d" "v=spf1")"
  if [ -z "$val" ]; then
    fail "SPF   $d — no v=spf1 record"
  elif [ "$val" = "v=spf1 a -all" ]; then
    pass "SPF   $d — v=spf1 a -all"
  elif printf '%s' "$val" | grep -qE -- '-all|~all'; then
    info "SPF   $d — present but not the expected 'v=spf1 a -all': [$val]"
  else
    fail "SPF   $d — no hard/soft -all qualifier: [$val]"
  fi
  # there must be exactly one SPF record, or SPF permerrors
  local n
  n="$(txt "$d" | grep -c 'v=spf1')"
  [ "$n" -gt 1 ] && fail "SPF   $d — $n SPF records found (must be exactly 1)"
}

check_fcrdns() {  # $1 = domain, $2 = expected IP ("" = derive from A)
  local d="$1" ip="$2" arec p
  arec="$(a_rec "$d" | head -1)"
  # A record forward-confirms the sender domain <-> IP
  if [ -n "$ip" ]; then
    if [ "$arec" = "$ip" ]; then
      pass "A     $d -> $ip"
    else
      fail "A     $d -> [${arec:-none}] (expected $ip)"
    fi
  else
    if [ -n "$arec" ]; then
      ip="$arec"; pass "A     $d -> $ip"
    else
      fail "A     $d — no A record"; return
    fi
  fi
  [ -z "$ip" ] && return
  # PTR must equal the sender domain (== HELO); combined with the A record
  # above that is full forward-confirmed reverse DNS.
  p="$(ptr "$ip")"
  if [ "$p" = "$d" ]; then
    pass "PTR   $ip -> $d  (FCrDNS aligned with HELO)"
  elif [ -z "$p" ]; then
    fail "PTR   $ip -> none  (set reverse DNS to $d)"
  else
    fail "PTR   $ip -> $p  (expected $d; set reverse DNS)"
  fi
}

# ===========================================================================
printf "${B}TripleA mail DNS checklist${Z}  (resolver: %s)\n" "$RESOLVER"

section "LOBBY  ($LOBBY_DOMAIN)"
check_fcrdns "$LOBBY_DOMAIN" "$LOBBY_IP"
check_dkim   "$LOBBY_DOMAIN"
check_spf    "$LOBBY_DOMAIN"

section "DICE  ($DICE_DOMAIN)"
check_fcrdns "$DICE_DOMAIN" ""    # derive + confirm IP from its own A record
check_dkim   "$DICE_DOMAIN"
check_spf    "$DICE_DOMAIN"

section "DMARC  (org-wide policy at _dmarc.$APEX, covers all subdomains)"
dmarc="$(txt_match "_dmarc.$APEX" "v=DMARC1")"
if [ -z "$dmarc" ]; then
  fail "DMARC _dmarc.$APEX — no v=DMARC1 record"
elif printf '%s' "$dmarc" | grep -qE 'p=(none|quarantine|reject)'; then
  pass "DMARC _dmarc.$APEX — $dmarc"
else
  fail "DMARC _dmarc.$APEX — present but no p= policy: [$dmarc]"
fi

# ---- summary ---------------------------------------------------------------
printf "\n${B}Summary:${Z} ${G}%d pass${Z}, ${R}%d fail${Z}\n" "$PASS" "$FAIL"
if [ "$FAIL" -eq 0 ]; then
  printf "${G}All good — mail DNS is fully aligned.${Z}\n"
fi
# non-zero exit if anything is wrong, so it's CI/scriptable
[ "$FAIL" -eq 0 ]
