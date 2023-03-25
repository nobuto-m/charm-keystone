#!/bin/bash

set -eux

juju destroy-model keystone-test --no-wait --force -y || true
juju add-model keystone-test maas
juju deploy ./keystone-ha_vault_edge.yaml
time juju-wait -w --exclude vault

VAULT_ADDR="http://$(juju run --unit vault/leader -- network-get certificates --ingress-address):8200"
export VAULT_ADDR

vault_init_output="$(vault operator init -key-shares=1 -key-threshold=1 -format json)"
vault operator unseal "$(echo "$vault_init_output" | jq -r .unseal_keys_b64[])"

VAULT_TOKEN="$(echo "$vault_init_output" | jq -r .root_token)"
export VAULT_TOKEN

juju run-action --wait vault/leader authorize-charm \
	token="$(vault token create -ttl=10m -format json | jq -r .auth.client_token)"
juju run-action vault/leader --wait generate-root-ca
