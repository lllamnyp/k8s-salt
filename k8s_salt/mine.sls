{% from './map.jinja' import k8s_salt %}
{% if salt['pillar.get']('k8s_salt:enabled') and salt['pillar.get']('k8s_salt:cluster') and k8s_salt %}
Send k8s data to mine:
  grains.present:
  - names:
    - k8s_salt:cluster:
      - value: {{ salt['pillar.get']('k8s_salt:cluster') }}
    - k8s_salt:roles:
      - value: {{ salt['pillar.get']('k8s_salt:roles') }}
      - force: True
    - k8s_salt:hostname_fqdn:
      - value: {{ k8s_salt['hostname_fqdn'] }}
    - k8s_salt:ip:
      - value: {{ k8s_salt['ip'] }}
    - k8s_salt:id:
      - value: {{ salt['grains.get']('id') }}
  module.run:
  - name: mine.send
  - m_name: get_k8s_data
  - kwargs:
      mine_function: grains.get
  - args:
    - k8s_salt
{% endif %}
