# Salt formula to manage k8s clusters

## Contents

### `.gitignore`

To bootstrap the cluster you need the following set of private keys placed under the right path:

```
pillar/files/kubernetes/<CLUSTER_NAME>/pki
│
├── kube-ca-key.pem          # Private key to (self)sign the kube-ca cert.
│
├── requestheader-ca-key.pem # Private key for the extension API server (necessary when integrating
│                            # with something like an RKE created cluster).
│
└── sa-key.pem               # Just a private RSA key. Kube-controller-manager uses it to sign tokens.

```
