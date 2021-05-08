{% if salt['pillar.get']('k8s_salt:roles:worker') %}
place_kubeproxy_files:
  file.managed:
  - makedirs: True
  - names:
    - /etc/kubernetes/pki/kube-ca.pem:
      - contents_pillar: k8s_certs:kube-ca
        mode: '0644'
    - /etc/kubernetes/config/kube-proxy-config.yaml:
      - source: salt://files/kubernetes/config/kube-proxy-config.yaml
        mode: '0644'
    - /etc/kubernetes/config/proxy.kubeconfig:
      - source: salt://files/kubernetes/config/proxy.kubeconfig
        mode: '0644'
        template: 'jinja'
  x509.certificate_managed:
  - makedirs: True
  - names:
    - /etc/kubernetes/pki/proxy.pem:
      - CN: system:kube-proxy
      - O: system:node-proxier
      - signing_private_key: {{ salt['pillar.get']('k8s_certs:kube-ca-key', '') | tojson }}
      - signing_cert: {{ salt['pillar.get']('k8s_certs:kube-ca', '') | tojson }}
      - managed_private_key:
          name: /etc/kubernetes/pki/proxy-key.pem
          bits: 2048
      - keyUsage: "critical Digital Signature, Key Encipherment"
      - extendedKeyUsage: "TLS Web Server Authentication, TLS Web Client Authentication"
      - basicConstraints: "critical CA:FALSE"

place_kubeproxy_service:
  file.managed:
  - name: /etc/systemd/system/kube-proxy.service
  - source: salt://files/kubernetes/systemd/kube-proxy.service
  - mode: 644
  - template: jinja

reload_kubeproxy_service:
  module.run:
  - name: service.systemctl_reload
  - onchanges:
    - file: place_kubeproxy_service

run_kubeproxy_unit:
  service.running:
  - name: kube-proxy
  - enable: True
  - watch:
    - module: reload_kubeproxy_service
{% endif %}
