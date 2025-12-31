import manifests
import schemas.kcl.digitalocean_kcl.models.v1beta1.digitalocean_crossplane_io_v1beta1_provider_config as do_provider
import k8s.apimachinery.pkg.apis.meta.v1 as meta
import configurations.common.prefilled_infisical_secret as I

do_api_token = I.InfisicalSecret {
    slug = "digitalocean-provider-token"
    keys = {
        "DIGITALOCEAN_ACCESS_TOKEN": "token"
    }
}

do_provider_config = do_provider.ProviderConfig {
    metadata = meta.ObjectMeta {
        name = "default"
    }
    spec = {
        credentials = {
            source = "Secret"
            secretRef = {
                namespace = "default"
                name = "digitalocean-provider-token"
                key = "DIGITALOCEAN_ACCESS_TOKEN"
            }
        }
    }
}

manifests.yaml_stream([
    do_api_token
    do_provider_config
])
