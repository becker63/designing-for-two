import schemas.kcl.fluxcd_helm_controller_kcl.models.v2 as fluxcd_release

fluxcd_release.HelmRelease {
    metadata.name = "crossplane"
    metadata.namespace = "crossplane-system"
    spec = {
        interval = "10m"
        chart = {
            spec = {
                chart = "crossplane"
                version = "1.17.3"
                sourceRef = {
                    kind = "HelmRepository"
                    name = "crossplane"
                    namespace = "crossplane-system"
                }
            }
        }
        install = {
            createNamespace = True
        }
    }
}
