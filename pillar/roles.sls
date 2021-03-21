{% import_yaml "roles.yaml" as r %}
roles:
{% if r[grains['id']] is defined %}
  {{ r[grains['id']]['roles']|tojson }}
{% else %}
  - none
{% endif %}
cluster: {% if r[grains['id']] is defined %}{{ r[grains['id']]['cluster']|tojson }}{% else %}none{% endif %}
