base:
  '*':
  - apt.base
  - users
  'roles:worker':
  - match: pillar
  - k8s.kubelet
  - k8s.proxy
  - k8s.haproxy
  'roles:controlplane':
  - match: pillar
  - k8s.apiserver
  - k8s.controller
  - k8s.scheduler
  'roles:etcd':
  - match: pillar
  - k8s.etcd
