import schemas.kcl.fluxcd_helm_controller_kcl.models.v2 as fluxcd_release

fluxcd_release.HelmRelease {
    metadata.name = "infisical-secrets-operator"
    metadata.namespace = "infisical"
    spec = {
        interval = "10m"
        chart = {
            spec = {
                chart = "secrets-operator"
                version = "0.1.0"
                sourceRef = {
                    kind = "HelmRepository"
                    name = "infisical"
                    namespace = "infisical"
                }
            }
        }
        install = {
            createNamespace = True
        }
    }
}
