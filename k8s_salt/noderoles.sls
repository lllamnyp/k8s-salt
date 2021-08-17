Create file with roles:
  file.managed:
  - makedirs: True
  - template: 'jinja'
  - names:
    - /etc/kubernetes/roles/roles.json:
      - source: salt://{{ slspath }}/templates/roles.json
