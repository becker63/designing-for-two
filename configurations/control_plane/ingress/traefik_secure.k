import schemas.kcl.traefik_kcl.models.v1alpha1.traefik_io_v1alpha1_ingress_route as traefik
import schemas.kcl.traefik_kcl.models.v1alpha1.traefik_io_v1alpha1_middleware as middleware
import configurations.common.prefilled_infisical_secret as I
import schemas.kcl.cert_manager_kcl.models.v1 as cert
import k8s.apimachinery.pkg.apis.meta.v1 as meta
import manifests

github_oidc = I.InfisicalSecret {
    slug = "github-oidc-secret"
    keys = {
        "GITHUB_OIDC_CLIENT_ID": "clientID"
        "GITHUB_OIDC_CLIENT_SECRET": "clientSecret"
    }
}

# --- 1. Middleware: ForwardAuth to oauth2-proxy ---
auth_middleware = middleware.Middleware {
    metadata = meta.ObjectMeta {
        name = "auth-forward"
        namespace = "default"
    }
    spec = {
        forwardAuth = {
            address = "http://oauth2-proxy.default.svc.cluster.local:4180"
            trustForwardHeader = True
            authResponseHeaders = [
                "X-Auth-Request-User"
                "X-Auth-Request-Email"
                "X-Auth-Request-Groups"
            ]
        }
    }
}

# --- 2. IngressRoute: Uses middleware and TLS via cert-manager ---
secure_route = traefik.IngressRoute {
    metadata = meta.ObjectMeta {
        name = "headlamp-websecure"
        namespace = "default"
    }
    spec = {
        entryPoints = ["websecure"]
        routes = [{
            match = "Host(`headlamp.example.com`)"
            kind = "Rule"
            services = [{
                name = "headlamp"
                port = 80
            }]
            middlewares = [{
                name = "auth-forward"
                namespace = "default"
            }]
        }]
        tls = {
            secretName = "headlamp-tls"
        }
    }
}

# --- 3. Certificate: Trigger cert-manager issuance via ClusterIssuer ---
cert_for_headlamp = cert.Certificate {
    metadata = meta.ObjectMeta {
        name = "headlamp-cert"
        namespace = "default"
    }
    spec = {
        secretName = "headlamp-tls"
        dnsNames = ["headlamp.example.com"]
        issuerRef = {
            name = "letsencrypt-prod"
            kind = "ClusterIssuer"
        }
    }
}

manifests.yaml_stream([
    github_oidc
    auth_middleware
    secure_route
    cert_for_headlamp
])
