{% from './map.jinja' import k8s_salt %}
{% if salt['pillar.get']('k8s_salt:roles:etcd') %}
get_etcd_archive:
  file.managed:
  - name: /data/etcd/etcd-{{ k8s_salt['version_etcd'] }}.tar.gz
  - source: {{ k8s_salt['etcd_proxy_repo'] }}/{{ k8s_salt['version_etcd'] }}/etcd-{{ k8s_salt['version_etcd'] }}-linux-{{ k8s_salt['arch'] }}.tar.gz
  - skip_verify: true
  - user: root
  - mode: 644
  - makedirs: True

unpack_etcd_archive:
  archive.extracted:
  - name: /data/etcd/{{ k8s_salt['version_etcd'] }}
  - source: /data/etcd/etcd-{{ k8s_salt['version_etcd'] }}.tar.gz
  - require:
    - get_etcd_archive

place_etcd_binaries:
  file.managed:
  - mode: '0755'
  - names:
    - /usr/local/bin/etcd:
      - source: /data/etcd/{{ k8s_salt['version_etcd'] }}/etcd-{{ k8s_salt['version_etcd'] }}-linux-{{ k8s_salt['arch'] }}/etcd
    - /usr/local/bin/etcdctl:
      - source: /data/etcd/{{ k8s_salt['version_etcd'] }}/etcd-{{ k8s_salt['version_etcd'] }}-linux-{{ k8s_salt['arch'] }}/etcdctl
  - require:
    - unpack_etcd_archive

  {% set authorities = salt['mine.get']('I@k8s_salt:roles:ca:True', 'get_authorities', 'compound').popitem()[1] %}
  {% set cluster = salt['pillar.get']('k8s_salt:cluster') %}
Etcd private keys:
  x509.private_key_managed:
  - replace: False
  - makedirs: True
  - names:
  {% for key in ['etcd-peer','etcd-trusted'] %}
    - /etc/kubernetes/pki/{{ key }}-key.pem:
      - bits: 4096
  {% endfor %}

Etcd X509 management:
  file.managed:
  - makedirs: True
  - names:
  {% for ca in ['etcd-peer-ca','etcd-trusted-ca'] %}
    - /etc/kubernetes/pki/{{ ca }}.pem:
      - contents: {{ authorities['/etc/kubernetes-authority/' + cluster + '/' + ca + '.pem'] | tojson }}
      - mode: '0644'
  {% endfor %}
  x509.certificate_managed:
  - makedirs: True
  - names:
  {% for key in ['etcd-peer','etcd-trusted'] %}
    - /etc/kubernetes/pki/{{ key }}.pem:
      - CN: {{ salt['grains.get']('k8s_salt:hostname_fqdn') }}
      - ca_server: {{ salt['mine.get']('I@k8s_salt:roles:ca:True', 'get_k8s_data', 'compound').popitem()[1]['id'] }}
      - public_key: /etc/kubernetes/pki/{{ key }}-key.pem
      - signing_policy: {{ cluster }}_{{ key }}-ca
      - keyUsage: "critical Digital Signature, Key Encipherment"
      - extendedKeyUsage: "TLS Web Server Authentication, TLS Web Client Authentication"
      - basicConstraints: "critical CA:FALSE"
      - subjectAltName: >-
          DNS:localhost,
          DNS:{{ salt['grains.get']('k8s_salt:hostname_fqdn') }},
          IP Address:127.0.0.1,
          IP Address:{{ salt['grains.get']('k8s_salt:ip') }}
  {% endfor %}

place_etcd_service:
  file.managed:
  - name: /etc/systemd/system/etcd.service
  - source: salt://{{ slspath }}/templates/etcd.service
  - mode: 644
  - template: jinja
  - defaults:
      k8s_salt: {{ k8s_salt }}
  module.run:
  - name: service.systemctl_reload
  - onchanges:
    - file: place_etcd_service
run_etcd_unit:
  service.running:
  - name: etcd
  - enable: True
  - watch:
    - module: place_etcd_service
{% endif %}
