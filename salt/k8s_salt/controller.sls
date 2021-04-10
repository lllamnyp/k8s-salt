{% if 'controlplane' in salt['pillar.get']('roles') %}

place_controller_files:
  file.managed:
  - makedirs: True
  - names:
    - /etc/kubernetes/pki/kube-ca.pem:
      - contents_pillar: k8s_certs:kube-ca
        mode: '0644'
    - /etc/kubernetes/pki/kube-ca-key.pem:
      - contents_pillar: k8s_certs:kube-ca-key
        mode: '0600'
    - /etc/kubernetes/pki/sa-key.pem:
      - contents_pillar: k8s_certs:sa-key
        mode: '0600'
    - /etc/kubernetes/config/controller.kubeconfig:
      - source: salt://files/kubernetes/config/controller.kubeconfig
        mode: '0644'
  x509.certificate_managed:
  - makedirs: True
  - names:
    - /etc/kubernetes/pki/controller.pem:
      - CN: system:kube-controller-manager
      - signing_private_key: {{ salt['pillar.get']('k8s_certs:kube-ca-key', '') | tojson }}
      - signing_cert: {{ salt['pillar.get']('k8s_certs:kube-ca', '') | tojson }}
      - managed_private_key:
          name: /etc/kubernetes/pki/controller-key.pem
          bits: 2048
      - keyUsage: "critical Digital Signature, Key Encipherment"
      - extendedKeyUsage: "TLS Web Client Authentication"

place_controller_service:
  file.managed:
  - name: /etc/systemd/system/kube-controller-manager.service
  - source: salt://files/kubernetes/systemd/kube-controller-manager.service
  - mode: '0644'
  - template: 'jinja'
  module.run:
  - name: service.systemctl_reload
  - onchanges:
    - file: place_controller_service

run_controller_unit:
  service.running:
  - name: kube-controller-manager
  - enable: True
  - watch:
    - module: place_controller_service
{% endif %}