install base utils:
  pkg.installed:
    - pkgs:
      - python3-m2crypto
{% if salt['pillar.get']('k8s_salt:roles:worker') %}
{% endif %}
