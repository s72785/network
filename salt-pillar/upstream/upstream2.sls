upstream:
  interface: up2
  nat66-interface: up2
  up-bandwidth: 12400
  down-bandwidth: 195000
  flows: 2048

port-forwarding:
  - proto: udp
    port: 1194
    to: 172.20.75.9:1194
