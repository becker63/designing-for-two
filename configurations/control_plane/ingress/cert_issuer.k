import schemas.kcl.cert_manager_kcl.models.v1 as cert
import k8s.apimachinery.pkg.apis.meta.v1 as meta
import manifests

# Toggle between production and staging
# Unless we explicitly override this, assume we're not in prod
prod_mode: bool = False

# Shared metadata
cluster_issuer_name: str = "letsencrypt-prod" if prod_mode else "letsencrypt-staging"

acme_server: str = "https://acme-v02.api.letsencrypt.org/directory" if prod_mode else "https://acme-staging-v02.api.letsencrypt.org/directory"

# ClusterIssuer definition
cluster_issuer = cert.ClusterIssuer {
    metadata = meta.ObjectMeta {
        name = cluster_issuer_name
    }
    spec = {
        acme = {
            email = "you@example.com"
            server = acme_server
            privateKeySecretRef = {
                name = cluster_issuer_name + "-account-key"
            }
            solvers = [{
                http01 = {
                    ingress = {
                        class = "traefik"
                    }
                }
            }]
        }
    }
}

manifests.yaml_stream([cluster_issuer])
