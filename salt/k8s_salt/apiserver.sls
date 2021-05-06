{% if salt['pillar.get']('k8s_salt:roles:controlplane') %}
place_apiserver_files:
  file.managed:
  - makedirs: True
  - names:
    - /etc/kubernetes/pki/kube-ca.pem:
      - contents_pillar: k8s_salt:certs:kube-ca
        mode: '0644'
    - /etc/kubernetes/pki/requestheader-ca.pem:
      - contents_pillar: k8s_salt:certs:requestheader-ca
        mode: '0644'

  x509.certificate_managed:
  - makedirs: True
  - names:
    - /etc/kubernetes/pki/apiserver.pem:
      - CN: kube-apiserver
      - signing_private_key: {{ salt['pillar.get']('k8s_salt:certs:kube-ca-key', '') | tojson }}
      - signing_cert: {{ salt['pillar.get']('k8s_salt:certs:kube-ca', '') | tojson }}
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
    - /etc/kubernetes/pki/proxy-client.pem:
      - CN: kube-apiserver-proxy-client
      - signing_private_key: {{ salt['pillar.get']('k8s_certs:requestheader-ca-key', '') | tojson }}
      - signing_cert: {{ salt['pillar.get']('k8s_certs:requestheader-ca', '') | tojson }}
      - managed_private_key:
          name: /etc/kubernetes/pki/proxy-client-key.pem
          bits: 2048
      - keyUsage: "critical Digital Signature, Key Encipherment"
      - extendedKeyUsage: "TLS Web Server Authentication, TLS Web Client Authentication"

place_apiserver_sa_public_key:
  x509.pem_managed:
  - makedirs: True
  - names:
    - /etc/kubernetes/pki/sa.pem:
      - text: {{ salt['x509.get_public_key'](salt['pillar.get']('k8s_certs:sa-key', '')) }}

place_k8s_apiserver_service:
  file.managed:
  - name: /etc/systemd/system/kube-apiserver.service
  - source: salt://files/kubernetes/systemd/kube-apiserver.service
  - mode: '0644'
  - template: 'jinja'
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
