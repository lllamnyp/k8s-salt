Make cluster name available to all:
  module.run:
  - name: mine.send
  - m_name: get_k8s_cluster
  - kwargs:
      mine_function: pillar.get
  - args:
    - k8s_salt:cluster

Make minion id available to all:
  module.run:
  - name: mine.send
  - m_name: get_minion_id
  - kwargs:
      mine_function: grains.get
  - args:
    - id
