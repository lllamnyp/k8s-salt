{% from './map.jinja' import k8s_salt %}

### Check if state worth running
{% if salt['pillar.get']('k8s_salt:roles:controlplane') and k8s_salt is defined %}
{% if ('ca_server' in k8s_salt) %}

  {% set cluster = salt['pillar.get']('k8s_salt:cluster') %}
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
  x509.certificate_managed:
  - makedirs: True
  - names:
  {% set policy = {'etcdclient':'etcd-trusted-ca','apiserver':'kube-ca','proxy-client':'requestheader-ca'} %}
  {% for key in ['etcdclient','apiserver','proxy-client'] %}
    - /etc/kubernetes/pki/{{ key }}.pem:
      - CN: {{ 'kube-apiserver-' + cluster }}
      - ca_server: {{ k8s_salt['ca_server'] }}
      - public_key: /etc/kubernetes/pki/{{ key }}-key.pem
      - signing_policy: {{ cluster }}_{{ policy[key] }}
      - keyUsage: "critical Digital Signature, Key Encipherment"
      - extendedKeyUsage: "TLS Web Server Authentication, TLS Web Client Authentication"
      - basicConstraints: "critical CA:FALSE"{% if key != 'proxy-client' %}
      - subjectAltName: >-
          DNS:localhost,
          DNS:{{ k8s_salt['hostname_fqdn'] }},
          IP Address:127.0.0.1,
          IP Address:{{ k8s_salt['ip'] }}{% if key == 'apiserver' %},
          IP Address:{{ k8s_salt['api_service_ip'] }},{% for ip in k8s_salt['api_extra_ips'] %}
          IP Address:{{ ip }},{% endfor %}{% for dn in k8s_salt['api_extra_dns'] %}
          DNS:{{ dn }},{% endfor %}
          DNS:kubernetes,
          DNS:kubernetes.default,
          DNS:kubernetes.default.svc,
          DNS:kubernetes.default.svc.{{ k8s_salt['cluster_domain'] }}{% endif %}{% endif %}
      - days_valid: 365
      - days_remaining: 90
  {% endfor %}

place_k8s_apiserver_service:
  file.managed:
  - name: /etc/systemd/system/kube-apiserver.service
  - source: salt://{{ slspath }}/templates/component.service
  - mode: '0644'
  - template: 'jinja'
  - defaults:
      k8s_salt: {{ k8s_salt }}
      component: kube-apiserver
      description: Kubernetes API Server
      version: {{ k8s_salt['version_kubernetes'] }}
      doc: https://github.com/kubernetes/kubernetes
      service_params: |-
        LimitNOFILE=65535
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

### End checks if state worth running
{% endif %}
{% endif %}
