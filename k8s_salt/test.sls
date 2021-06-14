{% set pillars = salt['pillar.get']('k8s_overdata') %}
Echo pillars:
  cmd.run:
  - name: |-
      echo "{{ pillars }}"
