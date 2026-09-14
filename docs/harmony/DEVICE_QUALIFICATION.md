# HarmonyOS NEXT Device Qualification

A HarmonyOS build is not considered production-ready from source compilation alone. Evidence must be collected on a real supported device.

## Core tunnel

- [ ] VPN authorization succeeds
- [ ] TUN interface is created
- [ ] Core starts exactly once
- [ ] Core stops cleanly
- [ ] Restart after stop works
- [ ] Extension destruction does not leave a running native session

## Network

- [ ] IPv4 TCP connectivity
- [ ] IPv4 UDP connectivity
- [ ] IPv6 connectivity
- [ ] DNS resolution through the tunnel
- [ ] No DNS leak under the tested routing policy
- [ ] Wi-Fi → cellular transition
- [ ] Cellular → Wi-Fi transition
- [ ] Sleep / wake recovery
- [ ] Reconnect after network loss

## Protocols

For every protocol promoted to `tested`:

- [ ] Import/parser evidence
- [ ] Core capability evidence
- [ ] Runtime configuration validation
- [ ] Real server handshake
- [ ] TCP traffic
- [ ] UDP traffic where applicable
- [ ] DNS
- [ ] Reconnect
- [ ] Profile/server switch

## Stability

- [ ] Long-running tunnel test
- [ ] Memory/resource observation
- [ ] Repeated connect/disconnect loop
- [ ] App process / extension lifecycle stress
- [ ] No native crash or ANR

## Release evidence

Record device model, HarmonyOS version, API level, application version, Core revision, test date and result. Do not mark a feature `tested` without this evidence.
