place_trusted_keys:
  file.managed:
    - makedirs: true
    - mode: 644
    - user: root
    - group: root
    - names:
      - /etc/apt/trusted.gpg.d/kubernetes.gpg:
        - source: https://packages.cloud.google.com/apt/doc/apt-key.gpg
