# Installing Pinniped w/ Helm
Pinniped requires namespaces to be created manually prior to installing either the supervisor or concierge

## Namespaces
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: pinniped-supervisor
  labels:
    app: pinniped-supervisor
```

## Installation

#### Installing the Supervisor
```bash
helm install pinniped-supervisor pinniped-supervisor-chart --namespace pinniped-supervisor --atomic --values <your-values.yaml>
```

`values.schema.json` validates the values you pass in; `helm lint`/`helm install`/`helm template`
will fail with a clear message if a required field is missing.

If you're using the bundled Ingress/Certificate, you'll need to set, per cluster:
```yaml
certificate:
  enabled: true
  dnsNames: [""]      # one entry per hostname this Supervisor serves (or disable: certificate.enabled: false)
  clusterIssuer: ""
  secretName: ""

ingress:
  enabled: true
  hosts: [""]         # same hostnames as certificate.dnsNames above (or disable: ingress.enabled: false)
```
The Ingress's TLS secret is independent of the bundled Certificate: set `ingress.tlsSecretName` to
point it at any Secret you like (e.g. one managed outside this chart). If `ingress.tlsSecretName` is
left empty, it falls back to `certificate.secretName` - so with the bundled Certificate enabled and
no `ingress.tlsSecretName` set, the Ingress automatically uses that Certificate's Secret. Only set
`ingress.tlsSecretName` explicitly when you want the Ingress to use a different Secret than
`certificate.secretName`.

`federationDomains[].spec.identityProviders[]` the same way:
```yaml
federationDomains:
  - name: my-federation-domain
    spec:
      issuer: "" # e.g. https://<one of ingress.hosts above>
      tls:
        secretName: "" # should match certificate.secretName above
      identityProviders:
        - displayName: ""
          objectRef:
            apiGroup: idp.supervisor.pinniped.dev
            kind: "" # OIDCIdentityProvider | LDAPIdentityProvider | ActiveDirectoryIdentityProvider | GitHubIdentityProvider
            name: my-idp
```

...then populate that provider's own `{name, spec}` entry (`spec` passed through as-is to its CRD)
and, if it needs one, a matching entry in its credential `*Secrets` list. See `values.yaml`'s inline
comment above each list for its exact `spec`/Secret shape:

| Provider | Identity provider list | Credential Secret list |
| --- | --- | --- |
| OIDC | `oidcIdentityProviders` | `oidcClientSecrets` (`{name, clientID, clientSecret}`) |
| LDAP | `ldapIdentityProviders` | `bindSecrets` (`{name, username, password}`) |
| Active Directory | `activeDirectoryIdentityProviders` | `bindSecrets` (`{name, username, password}`) |
| GitHub | `githubIdentityProviders` | `githubClientSecrets` (`{name, clientID, clientSecret}`) |

## Configuration

See `values.yaml` for the full set of configurable fields and their defaults. Highlights:

| Key | Purpose |
| --- | --- |
| `image.repository` / `.tag` / `.digest` / `.pullPolicy` | Supervisor image. `tag` defaults to `v<appVersion>` from `Chart.yaml`; `digest` defaults to the digest from Pinniped's official install manifest for that `appVersion` (clear it if you override `tag` independently). |
| `replicaCount`, `resources`, `nodeSelector`, `tolerations`, `affinity`, `priorityClassName` | Standard Deployment scheduling/sizing knobs. |
| `extraEnv`, `extraVolumes`, `extraVolumeMounts` | Extend the supervisor container. |
| `service.api.*` | Type/annotations for the aggregated APIService's backing Service. |
| `config.*` | Structured `pinniped.yaml` operator config rendered via the `pinniped-supervisor-static-config` ConfigMap. |
| `certificate.enabled` / `.dnsNames` | Toggle the cert-manager `Certificate` this chart creates for the front-door TLS secret, and its list of DNS SANs. Disable if you manage that Secret another way. |
| `ingress.enabled` / `.hosts` / `.tlsSecretName` | Toggle the Ingress fronting the endpoints, the hostnames it routes, and its TLS Secret (falls back to `certificate.secretName` when unset). |
| `federationDomains` / `oidcIdentityProviders` / `ldapIdentityProviders` / `activeDirectoryIdentityProviders` / `githubIdentityProviders` / `oidcClients` | Lists of `{name, spec}` - `spec` is passed through as-is. All default to `[]`. |
| `oidcClientSecrets` / `bindSecrets` / `githubClientSecrets` | Chart-managed credential Secrets, one list per identity provider type that needs one: `oidcIdentityProviders[]`, `ldapIdentityProviders[]`, `activeDirectoryIdentityProviders[]`, `githubIdentityProviders[]`. |
| `podDisruptionBudget.enabled` | Off by default; enable for multi-replica HA. |
| `extraManifests` | Arbitrary additional objects (e.g. a `NetworkPolicy`, an `ExternalSecret`), templated with `tpl` so they can reference `.Values`/`.Release`/`.Chart`. |
| `nameOverride` / `fullnameOverride` | Rename chart-created resources. Leave unset for existing installs |

## RBAC
Kubernetes RBAC policies are *not* controlled by these charts. Recommended to use RBAC Manager to configure these.
t to `[]`/no-op; once you add an entry to any of
them, that entry's own required fields (`name`, plus whichever fields the chart validates - see
"Configuration" above) are enforced the same way.

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

## RBAC
Kubernetes RBAC policies are *not* controlled by these charts. Recommended to use RBAC Manager to configure these.
