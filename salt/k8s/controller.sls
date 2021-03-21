{% if 'controlplane' in salt['pillar.get']('roles') %}
{% set k8sV = salt['pillar.get']('controlplane:version') %}
get_controller_binaries:
  file.managed:
    - name: /data/k8s-controlplane/{{ k8sV }}/kube-controller-manager
    - source: https://storage.googleapis.com/kubernetes-release/release/v{{ k8sV }}/bin/linux/amd64/kube-controller-manager
    - skip_verify: true
    - user: root
    - mode: 644
    - makedirs: True

place_controller_binaries:
  file.managed:
    - mode: '0755'
    - names:
      - /usr/local/bin/kube-controller-manager:
        - source: /data/k8s-controlplane/{{ k8sV }}/kube-controller-manager
    - require:
      - get_controller_binaries

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
