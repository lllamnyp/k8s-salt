{% if salt['pillar.get']('k8s_salt:roles:controlplane') %}
  {% set authorities = salt['mine.get']('I@k8s_salt:roles:ca:True', 'get_authorities', 'compound').popitem()[1] %}
  {% set cluster = salt['pillar.get']('k8s_salt:cluster') %}
  {% set sa_pubkey = salt['mine.get']('I@k8s_salt:roles:ca:True', 'get_' + cluster + '_sa_keypair', 'compound')popitem()[1]['/etc/kubernetes-authority/' + cluster + '/sa.pem'] %}
Apiserver private keys:
  x509.private_key_managed:
  - replace: False
  - makedirs: True
  - names:
  {% for key in ['etcdclient','apiserver','proxy-client'] %}
    - /etc/kubernetes/pki/{{ key }}-key.pem:
      - bits: 4096
  {% endfor %}

Apiserver X509 management:
  file.managed:
  - makedirs: True
  - names:
  {% for ca in ['kube-ca','etcd-trusted-ca','requestheader-ca'] %}
    - /etc/kubernetes/pki/{{ ca }}.pem:
      - contents: {{ authorities['/etc/kubernetes-authority/' + cluster + '/' + ca + '.pem'] | tojson }}
      - mode: '0644'
  {% endfor %}

  x509.certificate_managed:
  - makedirs: True
  - names:
  {% set policy = {'etcdclient':'etcd-trusted-ca','apiserver':'kube-ca','proxy-client':'requestheader-ca'} %}
  {% for key in ['etcdclient','apiserver','proxy-client'] %}
    - /etc/kubernetes/pki/{{ key }}.pem:
      - CN: {{ salt['grains.get']('k8s_salt:hostname_fqdn') }}
      - ca_server: {{ k8s_salt['ca_server'] }}
      - public_key: /etc/kubernetes/pki/{{ key }}-key.pem
      - signing_policy: {{ cluster }}_{{ policy[key] }}
      - keyUsage: "critical Digital Signature, Key Encipherment"
      - extendedKeyUsage: "TLS Web Server Authentication, TLS Web Client Authentication"
      - basicConstraints: "critical CA:FALSE"{% if key != 'proxy-client' %}
      - subjectAltName: >-
          DNS:localhost,
          DNS:{{ salt['grains.get']('k8s_salt:hostname_fqdn') }},
          IP Address:127.0.0.1,
          IP Address:{{ salt['grains.get']('k8s_salt:ip') }}{% if key == 'apiserver' %},
          IP Address:{{ k8s_salt['api_service_ip'] }},{% for ip in k8s_salt['api_extra_ips'] %}
          IP Address:{{ ip }},{% endfor %}
          DNS:kubernetes,
          DNS:kubernetes.default,
          DNS:kubernetes.default.svc,
          DNS:kubernetes.default.svc.{{ k8s_salt['cluster_domain'] }}{% endif %}{% endif %}
  {% endfor %}

place_apiserver_sa_public_key:
  x509.pem_managed:
  - makedirs: True
  - names:
    - /etc/kubernetes/pki/sa.pem:
      - text: {{ sa_pubkey | tojson }}

place_k8s_apiserver_service:
  file.managed:
  - name: /etc/systemd/system/kube-apiserver.service
  - source: salt://{{ slspath }}/templates/kube-apiserver.service
  - mode: '0644'
  - template: 'jinja'
  - defaults:
      k8s_salt: {{ k8s_salt }}
  module.run:
  - name: service.systemctl_reload
  - onchanges:
    - file: place_k8s_apiserver_service

run_k8s_apiserver_unit:
  service.running:
  - name: kube-apiserver
  - enable: True
  - watch:
    - module: place_k8s_apiserver_service
{% endif %}
