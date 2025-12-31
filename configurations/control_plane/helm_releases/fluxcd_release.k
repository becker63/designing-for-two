import schemas.kcl.fluxcd_helm_controller_kcl.models.v2 as fluxcd_release

fluxcd_release.HelmRelease {
    metadata.name = "fluxcd"
    metadata.namespace = "flux-system"
    spec = {
        interval = "10m"
        chart = {
            spec = {
                chart = "flux2"
                version = "2.10.0"
                sourceRef = {
                    kind = "HelmRepository"
                    name = "fluxcd"
                    namespace = "flux-system"
                }
            }
        }
        install = {
            createNamespace = True
        }
        values = {
            installCRDs = True
        }
    }
}
