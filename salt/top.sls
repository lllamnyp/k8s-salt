base:
  '*':
  - apt.base
  'k8s_salt:roles:ca':
  - match: pillar
  - k8s_salt.ca
  'k8s_salt:roles:worker':
  - match: pillar
  - k8s_salt.kubelet
  - k8s_salt.proxy
  - k8s_salt.haproxy
  'k8s_salt:roles:controlplane':
  - match: pillar
  - k8s_salt.apiserver
  - k8s_salt.controller
  - k8s_salt.scheduler
  'k8s_salt:roles:etcd':
  - match: pillar
  - k8s_salt.etcd
