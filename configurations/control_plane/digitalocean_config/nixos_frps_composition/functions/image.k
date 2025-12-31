import schemas.kcl.digitalocean_kcl.models.v1alpha1.custom_digitalocean_crossplane_io_v1alpha1_image as image
import configurations.control_plane.digitalocean_config.vars as globalvars
import k8s.apimachinery.pkg.apis.meta.v1
import manifests

_out_image = image.Image {
    metadata = v1.ObjectMeta {
        name = "managed_do_image_" + globalvars.shared.imageName
    }
    spec = {
        forProvider = {
            name = globalvars.shared.imageName
            url = "https://github.com/becker63/home_network/releases/download/v1.0.0/frps_nixos.qcow2"
            distribution = "nixos"
            regions = [globalvars.shared.region]
            description = "Our ustom nixos frps vm"
            tags = ["crossplane", "custom-image", "nixos", "networking"]
        }
        providerConfigRef = {
            name = "default"
        }
    }
}

manifests.yaml_stream(_out_image)
