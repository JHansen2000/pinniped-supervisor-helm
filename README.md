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

If you're using the bundled Ingress/Certificate (the default), you'll need to set, per cluster:
```yaml
certificate:
  hostname: ""       # DNS name for the cert-manager Certificate (or disable: certificate.enabled: false)
  clusterIssuer: ""
  secretName: ""

ingress:
  hostname: ""        # same DNS name as above (or disable: ingress.enabled: false)
```

None of the identity-federation lists (`federationDomains`, the four `*IdentityProviders` lists, the
three credential `*Secrets` lists) have a live default - nothing there is required until you add an
entry, and which lists you populate depends entirely on which upstream identity provider(s) you use.
All four identity provider types get identical chart-level support: a `{name, spec}` list for the
identity provider itself, plus a matching `*Secrets` list for whatever credential Secret its `spec`
references. For example, to federate one OIDC provider:
```yaml
federationDomains:
  - name: my-federation-domain
    spec:
      issuer: "" # e.g. https://<ingress.hostname above>
      tls:
        secretName: "" # should match certificate.secretName above
      identityProviders:
        - displayName: ""
          objectRef:
            apiGroup: idp.supervisor.pinniped.dev
            kind: OIDCIdentityProvider
            name: my-oidc-idp

oidcIdentityProviders:
  - name: my-oidc-idp
    spec:
      issuer: "" # the upstream OIDC provider's issuer URL
      tls:
        certificateAuthorityDataSource:
          kind: Secret
          name: "" # should match an oidcClientSecrets[] name below
          key: ca.crt
      client:
        secretName: "" # should match an oidcClientSecrets[] name below

oidcClientSecrets:
  - name: ""
    clientID: ""
    clientSecret: ""
```

...or, equivalently, to federate one LDAP provider instead:
```yaml
federationDomains:
  - name: my-federation-domain
    spec:
      issuer: "" # e.g. https://<ingress.hostname above>
      tls:
        secretName: "" # should match certificate.secretName above
      identityProviders:
        - displayName: ""
          objectRef:
            apiGroup: idp.supervisor.pinniped.dev
            kind: LDAPIdentityProvider
            name: my-ldap-idp

ldapIdentityProviders:
  - name: my-ldap-idp
    spec:
      host: ""
      bind:
        secretName: "" # should match a bindSecrets[] name below
      userSearch:
        base: ""
      groupSearch:
        base: ""

bindSecrets:
  - name: ""
    username: ""
    password: ""
```
ActiveDirectory (`activeDirectoryIdentityProviders` + `bindSecrets`) and GitHub
(`githubIdentityProviders` + `githubClientSecrets`) follow the same pattern; see `values.yaml` for
each list's example comment.

## Configuration

See `values.yaml` for the full set of configurable fields and their defaults. Highlights:

| Key | Purpose |
| --- | --- |
| `image.repository` / `.tag` / `.digest` / `.pullPolicy` | Supervisor image. `tag` defaults to `v<appVersion>` from `Chart.yaml`; `digest` defaults to the digest from Pinniped's official install manifest for that `appVersion` (clear it if you override `tag` independently). |
| `replicaCount`, `resources`, `nodeSelector`, `tolerations`, `affinity`, `priorityClassName` | Standard Deployment scheduling/sizing knobs. |
| `extraEnv`, `extraVolumes`, `extraVolumeMounts` | Extend the supervisor container without forking the chart. |
| `service.api.*` | Type/annotations for the aggregated APIService's backing Service. `service.oidc.*` is the front-door Service that Ingress routes to. |
| `config.*` | Structured `pinniped.yaml` operator config (API group suffix, TLS ciphers, audit mode, admission plugin denylist). Rendered via the `pinniped-supervisor-static-config` ConfigMap. |
| `certificate.enabled` | Toggle the cert-manager `Certificate` this chart creates for the front-door TLS secret. Disable if you manage that Secret another way. |
| `ingress.enabled` | Toggle the bundled nginx Ingress fronting the OIDC endpoints. `ingress.annotations`/`ingress.ingressClassName` are fully configurable. |
| `federationDomains` / `oidcIdentityProviders` / `ldapIdentityProviders` / `activeDirectoryIdentityProviders` / `githubIdentityProviders` / `oidcClients` | All six are lists of `{name, spec}` - `spec` is passed through as-is to the corresponding CRD's spec field, validated server-side by the CRD itself rather than re-modeled field-by-field in this chart. No identity provider type gets deeper chart-level support than another; all default to `[]`. |
| `oidcClientSecrets` / `bindSecrets` / `githubClientSecrets` | Chart-managed credential Secrets, one list per identity provider type that needs one: `oidcClientSecrets` (`{name, clientID, clientSecret}`, type `secrets.pinniped.dev/oidc-client`) for `oidcIdentityProviders[].spec.client.secretName`; `bindSecrets` (`{name, username, password}`, type `kubernetes.io/basic-auth`) for `ldapIdentityProviders[].spec.bind.secretName` and `activeDirectoryIdentityProviders[].spec.bind.secretName`; `githubClientSecrets` (`{name, clientID, clientSecret}`, type `secrets.pinniped.dev/github-client`) for `githubIdentityProviders[].spec.client.secretName`. |
| `podDisruptionBudget.enabled` | Off by default; enable for multi-replica HA. |
| `extraManifests` | Arbitrary additional objects (e.g. a `NetworkPolicy`, an `ExternalSecret`), templated with `tpl` so they can reference `.Values`/`.Release`/`.Chart`. |
| `nameOverride` / `fullnameOverride` | Rename chart-created resources. Leave unset for existing installs - the default reproduces today's `pinniped-supervisor-*` names exactly when the release is named `pinniped-supervisor`. |

Every value above has a safe, unchanged-behavior default except `certificate.*`/`ingress.hostname`,
which are unset but required by default (since `certificate.enabled`/`ingress.enabled` default to
`true`) - the chart will refuse to render until you supply them, or you disable the corresponding
`enabled` flag. The identity-federation lists default to `[]`/no-op; once you add an entry to any of
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
