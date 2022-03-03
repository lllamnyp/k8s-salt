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

Python3 M2Crypto on the CA server:
  salt.state:
  - tgt: 'I@k8s_salt:enabled:True and I@k8s_salt:roles:ca:True'
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
    - salt: Python3 M2Crypto on the CA server

{% for cluster in clusters %}
Python3 M2Crypto on {{ cluster }} controlplane:
  salt.state:
  - tgt: 'I@k8s_salt:enabled:True and ( I@k8s_salt:roles:etcd:True or I@k8s_salt:roles:controlplane:True or I@k8s_salt:roles:admin:True ) and I@k8s_salt:cluster:{{ cluster }}'
  - tgt_type: compound
  - sls:
    - {{ slspath }}.m2crypto

Distribute CA certs to {{ cluster }} controlplane:
  salt.state:
  - tgt: 'I@k8s_salt:enabled:True and ( I@k8s_salt:roles:etcd:True or I@k8s_salt:roles:controlplane:True or I@k8s_salt:roles:admin:True ) and I@k8s_salt:cluster:{{ cluster }}'
  - tgt_type: compound
  - sls:
    - {{ slspath }}.distribute_cas
  - pillar: *pillar
  - require:
    - salt: Generate CA certs
    - salt: Python3 M2Crypto on {{ cluster }} controlplane

Build etcd in {{ cluster }}:
  salt.state:
  - tgt: 'I@k8s_salt:enabled:True and ( I@k8s_salt:roles:etcd:True or I@k8s_salt:roles:admin:True ) and I@k8s_salt:cluster:{{ cluster }}'
  - tgt_type: compound
  - sls:
    - {{ slspath }}.etcd
  - pillar: *pillar
  - require:
    - salt: Distribute CA certs to {{ cluster }} controlplane
    - cmd: Allow minions to request certs
    - salt: Python3 M2Crypto on {{ cluster }} controlplane

Run {{ cluster }} controlplane:
  salt.state:
  - tgt: 'I@k8s_salt:enabled:True and I@k8s_salt:roles:controlplane:True and I@k8s_salt:cluster:{{ cluster }}'
  - tgt_type: compound
  - sls:
    - {{ slspath }}.apiserver
    - {{ slspath }}.controller
    - {{ slspath }}.scheduler
  - pillar: *pillar
  - require:
    - salt: Build etcd in {{ cluster }}
    - cmd: Allow minions to request certs
    - salt: Python3 M2Crypto on {{ cluster }} controlplane

Python3 M2Crypto on {{ cluster }} workers:
  salt.state:
  - tgt: 'I@k8s_salt:enabled:True and I@k8s_salt:roles:worker:True and I@k8s_salt:cluster:{{ cluster }}'
  - tgt_type: compound
  - sls:
    - {{ slspath }}.m2crypto

Distribute CA certs to {{ cluster }} workers:
  salt.state:
  - tgt: 'I@k8s_salt:enabled:True and I@k8s_salt:roles:worker:True and I@k8s_salt:cluster:{{ cluster }}'
  - tgt_type: compound
  - sls:
    - {{ slspath }}.distribute_cas
  - pillar: *pillar
  - require:
    - salt: Generate CA certs
    - salt: Python3 M2Crypto on {{ cluster }} workers

Start {{ cluster }} haproxies:
  salt.state:
    # TODO: what if the list of targets is empty? e.g. no workers
  - tgt: 'I@k8s_salt:enabled:True and ( I@k8s_salt:roles:worker:True or I@k8s_salt:roles:admin:True ) and I@k8s_salt:cluster:{{ cluster }}'
  - tgt_type: compound
  - sls:
    - {{ slspath }}.haproxy
  - pillar: *pillar
  - require:
    - salt: Run {{ cluster }} controlplane
    - salt: Python3 M2Crypto on {{ cluster }} workers
    - cmd: Allow minions to request certs

Start {{ cluster }} adminbox:
  salt.state:
  - tgt: 'I@k8s_salt:enabled:True and I@k8s_salt:roles:admin:True and I@k8s_salt:cluster:{{ cluster }}'
  - tgt_type: compound
  - sls:
    - {{ slspath }}.admin
  - pillar: *pillar
  - require:
    - salt: Start {{ cluster }} haproxies
    - salt: Run {{ cluster }} controlplane
    - salt: Python3 M2Crypto on {{ cluster }} controlplane
    - cmd: Allow minions to request certs

Assign roles to {{ cluster }} nodes:
  salt.state:
  - tgt: 'I@k8s_salt:enabled:True and ( I@k8s_salt:roles:admin:True or I@k8s_salt:roles:worker:True ) and I@k8s_salt:cluster:{{ cluster }}'
  - tgt_type: compound
  - sls:
    - {{ slspath }}.noderoles
  - require:
    - salt: Start {{ cluster }} adminbox

Deploy {{ cluster }} manifests:
  salt.state:
  - tgt: 'I@k8s_salt:enabled:True and I@k8s_salt:roles:admin:True and I@k8s_salt:cluster:{{ cluster }}'
  - tgt_type: compound
  - sls:
    - {{ slspath }}.cluster_manifests
  - pillar: *pillar
  - require:
    - salt: Start {{ cluster }} adminbox

Deploy {{ cluster }} addons:
  salt.state:
  - tgt: 'I@k8s_salt:enabled:True and I@k8s_salt:roles:admin:True and I@k8s_salt:cluster:{{ cluster }}'
  - tgt_type: compound
  - sls:
    - {{ slspath }}.addons
  - pillar: *pillar
  - require:
    - salt: Start {{ cluster }} adminbox

Start {{ cluster }} workers:
  salt.state:
  - tgt: 'I@k8s_salt:enabled:True and I@k8s_salt:roles:worker:True and I@k8s_salt:cluster:{{ cluster }}'
  - tgt_type: compound
  - sls:
    - {{ slspath }}.cni
    - {{ slspath }}.kubelet
    - {{ slspath }}.proxy
  - pillar: *pillar
  - require:
    - salt: Start {{ cluster }} haproxies
    - salt: Python3 M2Crypto on {{ cluster }} workers
    - cmd: Allow minions to request certs
{% endfor %}
