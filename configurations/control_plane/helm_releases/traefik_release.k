import schemas.kcl.fluxcd_helm_controller_kcl.models.v2 as fluxcd_release

fluxcd_release.HelmRelease {
    metadata.name = "traefik"
    metadata.namespace = "traefik"
    spec = {
        interval = "10m"
        chart = {
            spec = {
                chart = "traefik"
                version = "21.2.0"
                sourceRef = {
                    kind = "HelmRepository"
                    name = "traefik"
                    namespace = "traefik"
                }
            }
        }
        install = {
            createNamespace = True
        }
    }
}
