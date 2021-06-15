{% from './orch.jinja' import inverted_roles, clusters, host_info, ca_server %}

Allow minions to request certs:
  file.managed:
  - names:
    - /etc/salt/master.d/peer.conf:
      - source: salt://{{ slspath }}/templates/peer.conf
  cmd.run:
  - name: 'sleep 5; salt-call service.restart salt-master'
  - bg: True
  - onchanges:
    - file: Allow minions to request certs

Stop execution salt must restart:
  test.fail_without_changes:
  - comment: "The salt master was restarted for reconfiguration, run the overstate again"
  - onchanges:
    - cmd: Allow minions to request certs
  - failhard: True

Download k8s binaries:
  salt.state:
  - tgt: 'I@k8s_salt:enabled:True'
  - tgt_type: compound
  - sls:
    - {{ slspath }}.binaries
  - pillar: &pillar
      k8s_overdata:
        inverted_roles: {{ inverted_roles }}
        clusters: {{ clusters }}
        host_info: {{ host_info }}
        ca_server: {{ ca_server }}

Python3 M2Crypto for signing certs:
  salt.state:
  - tgt: 'I@k8s_salt:enabled:True'
  - tgt_type: compound
  - sls:
    - {{ slspath }}.m2crypto

Enable signing policies on ca:
  salt.state:
  - tgt: 'I@k8s_salt:enabled:True and I@k8s_salt:roles:ca:True'
  - tgt_type: compound
  - sls:
    - {{ slspath }}.ca_signing_policies
  - pillar: *pillar

{% if 'id' in ca_server %}
Wait for ca reboot:
  salt.wait_for_event:
  - name: salt/minion/*/start
  - id_list:
    - {{ ca_server['id'] }}
  - onchanges:
    - salt: Enable signing policies on ca
{% endif %}

Generate CA certs:
  salt.state:
  - tgt: 'I@k8s_salt:enabled:True and I@k8s_salt:roles:ca:True'
  - tgt_type: compound
  - sls:
    - {{ slspath }}.ca
  - pillar: *pillar
  - require:
    - salt: Wait for ca reboot
    - salt: Python3 M2Crypto for signing certs

Distribute CA certs:
  salt.state:
  - tgt: 'I@k8s_salt:enabled:True'
  - tgt_type: compound
  - sls:
    - {{ slspath }}.distribute_cas
  - pillar: *pillar
  - require:
    - salt: Generate CA certs

Build etcd clusters:
  salt.state:
  - tgt: 'I@k8s_salt:enabled:True and ( I@k8s_salt:roles:etcd:True or I@k8s_salt:roles:admin:True ) '
  - tgt_type: compound
  - sls:
    - {{ slspath }}.etcd
  - pillar: *pillar
  - require:
    - salt: Distribute CA certs
    - cmd: Allow minions to request certs

Run controlplane:
  salt.state:
  - tgt: 'I@k8s_salt:enabled:True and I@k8s_salt:roles:controlplane:True'
  - tgt_type: compound
  - sls:
    - {{ slspath }}.apiserver
    - {{ slspath }}.controller
    - {{ slspath }}.scheduler
  - pillar: *pillar
  - require:
    - salt: Build etcd clusters
    - cmd: Allow minions to request certs

Start haproxies:
  salt.state:
  - tgt: 'I@k8s_salt:enabled:True and I@k8s_salt:roles:worker:True'
  - tgt_type: compound
  - sls:
    - {{ slspath }}.haproxy
  - pillar: *pillar
  - require:
    - salt: Run controlplane
    - cmd: Allow minions to request certs

Start workers:
  salt.state:
  - tgt: 'I@k8s_salt:enabled:True and I@k8s_salt:roles:worker:True'
  - tgt_type: compound
  - sls:
    - {{ slspath }}.cni
    - {{ slspath }}.kubelet
    - {{ slspath }}.proxy
  - pillar: *pillar
  - require:
    - salt: Start haproxies
    - cmd: Allow minions to request certs
