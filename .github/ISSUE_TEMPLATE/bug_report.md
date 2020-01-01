---
name: Bug report
about: There is a problem with the WireGuard package
title: ''
labels: ''
assignees: ''

---

**Description**
Brief description of what you are trying to do, and what actually happens.

**Steps to reproduce**
```
$ ssh user@nas
$ sudo wg-quick up wg0
[#] ip link add wg0 type wireguard
[#] wg setconf wg0 /dev/fd/63
[#] ip -4 address add 10.0.0.2/16 dev wg0
[#] ip link set mtu 1270 up dev wg0
[#] wg set wg0 fwmark 51820
[#] ip -4 route add 0.0.0.0/0 dev wg0 table 51820
[#] ip -4 rule add not fwmark 51820 table 51820
[#] ip -4 rule add table main suppress_prefixlength 0
[#] sysctl -q net.ipv4.conf.all.src_valid_mark=1
[#] nft -f /dev/fd/63
$ sudo wg show
interface: wg0
  public key: <redacted>
  private key: (hidden)
  listening port: 25565
  fwmark: 0xca6c
```

**Expected behavior**
A clear and concise description of what you expected to happen.

**Synology NAS model**
E.g. DS218j

**wg0.conf**
```
Content of wg0.conf goes here. Remember to redact Private keys!
```

If there are multiple peers, include their configuration too.
