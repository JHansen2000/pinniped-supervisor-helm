# Installing Pinniped Supervisor w/ Helm

## Install
```bash
helm install pinniped-supervisor pinniped-supervisor-helm --namespace pinniped-supervisor --atomic --values <your-values.yaml>
```

## TLS Certificates

`defaultTLSCertificate` satisfies Pinniped's own required default serving cert - used for any
HTTPS request whose SNI doesn't match a `FederationDomain`'s own `spec.tls.secretName`. Pinniped
does **not** generate this itself; without it, requests fail with `pinniped supervisor has invalid
TLS serving certificate configuration`. Self-signed by default - nothing external needs to trust it.
https://pinniped.dev/docs/howto/supervisor/configure-supervisor/

`ingress.certificate` is separate: what the Ingress presents to real clients, needs a real issuer.
Off by default since some ingress controllers (e.g. Traefik) present their own default cert
instead. The two Secrets are always named internally and can never collide.

## Identity providers

`federationDomains` / `oidcIdentityProviders` / `ldapIdentityProviders` /
`activeDirectoryIdentityProviders` / `githubIdentityProviders` / `oidcClients` are each a list of
`{name, spec}` - `spec` passed through as-is to the CRD. See `values.yaml`'s inline comments for
shape.

| Provider | List | Credential Secret list |
| --- | --- | --- |
| OIDC | `oidcIdentityProviders` | `oidcClientSecrets` (`{name, clientID, clientSecret}`) |
| LDAP | `ldapIdentityProviders` | `bindSecrets` (`{name, username, password}`) |
| Active Directory | `activeDirectoryIdentityProviders` | `bindSecrets` (`{name, username, password}`) |
| GitHub | `githubIdentityProviders` | `githubClientSecrets` (`{name, clientID, clientSecret}`) |

### Existing Secrets

Set `existingSecret: true` on a credential Secret entry to reference a Secret you manage yourself. `name` is the existing Secret's name. Pinniped requires a fixed type and keys:

| List | Type | Keys |
| --- | --- | --- |
| `oidcClientSecrets` | `secrets.pinniped.dev/oidc-client` | `clientID`, `clientSecret` |
| `bindSecrets` | `kubernetes.io/basic-auth` | `username`, `password` |
| `githubClientSecrets` | `secrets.pinniped.dev/github-client` | `clientID`, `clientSecret` |

If your source Secret uses different key names, remap them with an External Secrets Operator
`ExternalSecret` in `extraManifests`. 
```yaml
bindSecrets:
  - name: ad-bind
    existingSecret: true

extraManifests:
  - apiVersion: external-secrets.io/v1
    kind: ExternalSecret
    metadata:
      name: ad-bind
    spec:
      secretStoreRef: {kind: ClusterSecretStore, name: vault}
      target:
        name: ad-bind
        template:
          type: kubernetes.io/basic-auth
          data:
            username: '{{ "{{ .bindUser }}" }}'
            password: '{{ "{{ .bindPw }}" }}'
      data:
        - {secretKey: bindUser, remoteRef: {key: ad, property: user}}
        - {secretKey: bindPw, remoteRef: {key: ad, property: pw}}
```

## Configuration

Full field list/defaults in `values.yaml`.

| Key | Purpose |
| --- | --- |
| `image.tag` / `.digest` | Default to `v<appVersion>` / Pinniped's official manifest digest for that version. |
| `replicaCount`, `resources`, `nodeSelector`, `tolerations`, `affinity` | Standard Deployment scheduling/sizing knobs. |
| `extraEnv`, `extraVolumes`, `extraVolumeMounts` | Extend the supervisor container without forking the chart. |
| `service.api.*` / `service.oidc.*` | Aggregated-APIService Service vs. the OIDC front-door Service that Ingress routes to. |
| `config.*` | Structured `pinniped.yaml` operator config, rendered into the static-config ConfigMap. |
| `defaultTLSCertificate` / `ingress.certificate` | See TLS section above. |
| `oidcClientSecrets` / `bindSecrets` / `githubClientSecrets` | Chart-managed credential Secrets backing the identity provider lists above, or `existingSecret: true` to reference your own. |
| `podDisruptionBudget.enabled` | Off by default. |
| `extraManifests` | Arbitrary objects, templated with `tpl`. |
| `nameOverride` / `fullnameOverride` | Rename chart-created resources. |

## Installing the Pinniped CLI
```bash
# Homebrew
brew install vmware/pinniped/pinniped-cli
```

## Getting a Kubeconfig:
```bash
# This command gets a kubeconfig from the upstream server
# it uses an OIDC provider named "Keycloak OIDC" and
# stores the resulting file in ~/.kube/pinniped

pinniped get kubeconfig --kubeconfig="~/.kube/config" --upstream-identity-provider-name "Keycloak OIDC" --upstream-identity-provider-type oidc > ~/.kube/pinniped
```
