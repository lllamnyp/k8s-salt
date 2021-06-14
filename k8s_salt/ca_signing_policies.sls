{% from './map.jinja' import k8s_salt %}
{% set clusters = salt['pillar.get']('k8s_overdata:clusters') %}

Place signing policy on CA server:
  file.managed:
  - names:
    - /etc/salt/minion.d/signing_policies.conf:
      - source: salt://{{ slspath }}/templates/signing_policies.conf
      - template: jinja
      - defaults:
          k8s_salt: {{ k8s_salt }}
          clusters: {{ clusters }}
  cmd.run:
  - name: 'sleep 5; salt-call service.restart salt-minion'
  - bg: True
  - onchanges:
    - file: Place signing policy on CA server

