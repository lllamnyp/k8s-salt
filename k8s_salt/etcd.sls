{% from './map.jinja' import k8s_salt %}

{% if k8s_salt and ('ip' in k8s_salt) %}
{% if salt['pillar.get']('k8s_salt:roles:etcd') or salt['pillar.get']('k8s_salt:roles:admin') %}
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
  {% if salt['pillar.get']('k8s_salt:roles:etcd') %}
    - /usr/local/bin/etcd:
      - source: /data/etcd/{{ k8s_salt['version_etcd'] }}/etcd-{{ k8s_salt['version_etcd'] }}-linux-{{ k8s_salt['arch'] }}/etcd
  {% endif %}
    - /usr/local/bin/etcdctl:
      - source: /data/etcd/{{ k8s_salt['version_etcd'] }}/etcd-{{ k8s_salt['version_etcd'] }}-linux-{{ k8s_salt['arch'] }}/etcdctl
  - require:
    - unpack_etcd_archive

  {% set keys = ['etcd-trusted'] %}
  {% if salt['pillar.get']('k8s_salt:roles:etcd') %}
    {% do keys.append('etcd-peer') %}
  {% endif %}
Etcd private keys:
  x509.private_key_managed:
  - replace: False
  - makedirs: True
  - names:
  {% for key in keys %}
    - /etc/kubernetes/pki/{{ key }}-key.pem:
      - bits: 4096
  {% endfor %}

  {% set cluster = salt['pillar.get']('k8s_salt:cluster') %}
Etcd X509 management:
  x509.certificate_managed:
  - makedirs: True
  - names:
  {% for key in keys %}
    - /etc/kubernetes/pki/{{ key }}.pem:
      - CN: {{ salt['grains.get']('k8s_salt:hostname_fqdn') }}
      - ca_server: {{ k8s_salt['ca_server'] }}
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

  {% if salt['pillar.get']('k8s_salt:roles:etcd') %}
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
{% endif %}
{% endif %}
