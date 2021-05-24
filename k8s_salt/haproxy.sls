{% from './map.jinja' import k8s_salt %}

# TODO: needs validity checks (if k8s_salt is defined, etc)

{% if salt['pillar.get']('k8s_salt:roles:worker') and not salt['pillar.get']('k8s_salt:roles:controlplane')  %}
  {% set cluster = salt['pillar.get']('k8s_salt:cluster') %}
# TODO: look for alternatives for rpm-based systems
# TODO: try non-root?
add_trusted_haproxy_repo:
  file.managed:
  - name: /etc/apt/sources.list.d/haproxy.list
  - user: root
  - group: root
  - mode: 644
  - contents: |
      deb [trusted=yes] http://ppa.launchpad.net/vbernat/haproxy-2.3/ubuntu bionic main

update_haproxy_repo:
  cmd.wait:
  - name: apt-get update > /dev/null || true
  - watch:
    - file: add_trusted_haproxy_repo

install_haproxy_package:
  pkg.installed:
  - name: haproxy
  - pkgs:
    - haproxy: '2.*'
  - hold: True
  - refresh: True
  - cache_valid_time: 86400 # 1 day
  - version: '2.*'
  - require:
    - file: add_trusted_haproxy_repo
    - cmd: update_haproxy_repo

Healthchecker private key:
  x509.private_key_managed:
  - replace: False
  - makedirs: True
  - names:
    - /etc/kubernetes/pki/health-checker-key.pem:
      - bits: 4096

place_haproxy_configuration:
  file.managed:
  - makedirs: True
  - names:
    - /etc/logrotate.d/haproxy_logrotate:
      - source: salt://{{ slspath }}/templates/haproxy_logrotate
        mode: '0644'
      # TODO: later
      #      - /etc/rsyslog.d/40-haproxy_rsyslog.conf:
      #        - source: salt://{{ slspath }}/templates/40-haproxy_rsyslog.conf
      #          mode: '0644'
    - /etc/haproxy/haproxy.cfg:
      - source: salt://{{ slspath }}/templates/haproxy.cfg
        mode: '0644'
        template: 'jinja'
  x509.certificate_managed:
  - makedirs: True
  - names:
    - /etc/kubernetes/pki/health-checker.pem:
      - CN: health-checker # system:authenticated should be enough to check https://<API>/healthz
      - ca_server: {{ k8s_salt['ca_server'] }}
      - public_key: /etc/kubernetes/pki/health-checker-key.pem
      - signing_policy: {{ cluster }}_kube-ca
      - basicConstraints: "critical CA:FALSE"
      - keyUsage: "critical Digital Signature, Key Encipherment"
      - extendedKeyUsage: "TLS Web Server Authentication, TLS Web Client Authentication"
  cmd.run:
  - names:
    - 'cat /etc/kubernetes/pki/health-checker-key.pem /etc/kubernetes/pki/health-checker.pem > /etc/kubernetes/pki/health-checker-bundle.pem':
      - onchanges:
        - x509: place_haproxy_configuration

remove_wrong_conf:
  file.absent:
  - name: /etc/rsyslog.d/49-haproxy.conf

run_haproxy_service:
  service.running:
  - name: haproxy
  - enable: True
  - reload: True
  - onchanges:
    - cmd: place_haproxy_configuration

# TODO: later
# reload_rsyslog_service:
#   service.running:
#     - name: rsyslog
#     - enable: True
#     - watch:
#       - file: place_haproxy_configuration
{% endif %}
