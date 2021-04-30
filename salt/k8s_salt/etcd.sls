include:
- .defaults

{% if 'etcd' in salt['pillar.get']('k8s_salt:roles') %}
get_etcd_archive:
  file.managed:
  - name: /data/etcd/etcd-{{ etcd_version }}.tar.gz
  - source: {{ etcd_repo }}/{{ etcd_version }}/etcd-{{ etcd_version }}-linux-{{ arch }}.tar.gz
  - skip_verify: true
  - user: root
  - mode: 644
  - makedirs: True

unpack_etcd_archive:
  archive.extracted:
  - name: /data/etcd/{{ etcd_version }}
  - source: /data/etcd/etcd-{{ etcd_version }}.tar.gz
  - require:
    - get_etcd_archive
place_etcd_binaries:
  file.managed:
  - mode: '0755'
  - names:
    - /usr/local/bin/etcd:
      - source: /data/etcd/{{ etcd_version }}/etcd-{{ etcd_version }}-linux-{{ arch }}/etcd
    - /usr/local/bin/etcdctl:
      - source: /data/etcd/{{ etcd_version }}/etcd-{{ etcd_version }}-linux-{{ arch }}/etcdctl
  - require:
    - unpack_etcd_archive

place_etcd_certs:
  file.managed:
  - makedirs: True
  - names:
    - /etc/kubernetes/pki/kube-ca.pem:
      - contents_pillar: k8s_certs:kube-ca
        mode: '0644'
#     - /etc/kubernetes/pki/apiserver.pem:
#       - contents_pillar: k8s_certs:apiserver
#         mode: '0644'
#     - /etc/kubernetes/pki/apiserver-key.pem:
#       - contents_pillar: k8s_certs:apiserver-key
#         mode: '0600'
  x509.certificate_managed:
  - makedirs: True
  - names:
    - /etc/kubernetes/pki/apiserver.pem:
      - CN: kube-apiserver
      - signing_private_key: {{ salt['pillar.get']('k8s_certs:kube-ca-key', '') | tojson }}
      - signing_cert: {{ salt['pillar.get']('k8s_certs:kube-ca', '') | tojson }}
      - managed_private_key:
          name: /etc/kubernetes/pki/apiserver-key.pem
          bits: 2048
      - keyUsage: "critical Digital Signature, Key Encipherment"
      - extendedKeyUsage: "TLS Web Server Authentication, TLS Web Client Authentication"
      - basicConstraints: "critical CA:FALSE"
      - subjectAltName: >-
          DNS:localhost,
          DNS:kubernetes,
          DNS:kubernetes.default,
          DNS:kubernetes.default.svc,
          DNS:kubernetes.default.svc.cluster.local,
          IP Address:{{salt['grains.get']('fqdn_ip4')[0]}},
          IP Address:10.43.0.1,
          IP Address:127.0.0.1

place_etcd_service:
  file.managed:
  - name: /etc/systemd/system/etcd.service
  - source: salt://files/kubernetes/systemd/etcd.service
  - mode: 644
  - template: jinja
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
