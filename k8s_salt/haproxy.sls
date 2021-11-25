{% from './map.jinja' import k8s_salt %}

Noop if this is a controlplane node:
  test.nop
# TODO: needs validity checks (if k8s_salt is defined, etc)

{% if ('hostname_fqdn' in k8s_salt) and ('ca_server' in k8s_salt) %}
{% if ( salt['pillar.get']('k8s_salt:roles:worker') or salt['pillar.get']('k8s_salt:roles:admin') ) and not salt['pillar.get']('k8s_salt:roles:controlplane')  %}
  {% set cluster = salt['pillar.get']('k8s_salt:cluster') %}

{% if grains['os_family'] == 'Debian' %}
add_haproxy_repo_key:
  cmd.run:
    - name: wget -O - {{ k8s_salt['haproxy_proxy_repo_key_url'] }} | apt-key add -
    - unless: apt-key list | grep 'HAProxy'
{% endif %}

add_haproxy_repo:
{% if grains['os_family'] == 'Debian' %}
  pkgrepo.managed:
    - humanname: HAProxy
    - name: deb {{ k8s_salt['haproxy_proxy_repo'] }}/{{ grains['os']|lower }}-{{ grains['oscodename']|lower }}/ {{ grains['oscodename']|lower }} main
    - dist: {{ grains['oscodename']|lower }}
    - gpgcheck: 1
    - key_url: {{ k8s_salt['haproxy_proxy_repo_key_url'] }}
    - require:
      - cmd: add_haproxy_repo_key
{% else %}
  test.show_notification:
    - text:  Unimplemented for your OS {{ grains['os'] }}, welcome for PR.
{% endif %}

install_haproxy_package:
  pkg.installed:
  - name: haproxy
  - pkgs:
    - haproxy: '2.3.*'
  - hold: True
  - refresh: True
  - cache_valid_time: 86400 # 1 day
  - version: '2.3.*'
  - require:
    - add_haproxy_repo

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
      - mode: '0644'
# TODO: later
#       - /etc/rsyslog.d/40-haproxy_rsyslog.conf:
#         - source: salt://{{ slspath }}/templates/40-haproxy_rsyslog.conf
#         - mode: '0644'
    - /etc/haproxy/haproxy.cfg:
      - source: salt://{{ slspath }}/templates/haproxy.cfg
      - mode: '0644'
      - template: 'jinja'
      - defaults:
          k8s_salt: {{ k8s_salt }}
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
  - check_cmd:
# TODO: unhardcode port
# TODO: correct approach could be done better
    - "curl https://localhost:6443 -k || ( systemctl reload haproxy && sleep 3 && curl https://localhost:6443 -k )"
  - retry:
      attempts: 5
      interval: 5
      splay: 2

# TODO: later
# reload_rsyslog_service:
#   service.running:
#     - name: rsyslog
#     - enable: True
#     - watch:
#       - file: place_haproxy_configuration
{% endif %}
{% endif %}
