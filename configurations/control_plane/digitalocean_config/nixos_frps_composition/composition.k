import schemas.kcl.crossplane_kcl_function_kcl.models.v1alpha1.krm_kcl_dev_v1alpha1_k_c_l_input as func
import schemas.kcl.crossplane_kcl.models.v1.apiextensions_crossplane_io_v1_composition as compdef
import schemas.kcl.crossplane_kcl.models.v1.apiextensions_crossplane_io_v1_composite_resource_definition as crd
import configurations.control_plane.digitalocean_config.vars as globalvars
import k8s.apimachinery.pkg.apis.meta.v1
import file
import manifests

KIND = "digitalocean-config"
GROUP = "becker.cloud"
PLURAL = "digitalocean-configs"
COMPOSITION_NAME = "digitalocean-config-comp"
XR_NAME = "digitalocean-config"

DEPENDENCIES = """

                k8s = "1.31.2"
                home_network = { git = "https://github.com/becker63/home_network/", commit = "8559064", version = "0.0.2" }

                """

generate_function_meta = lambda filepath: str, step: str {
    _filename = filepath.split("/")[-1]
    _slug = _filename.split(".")[0]

    {
        step = step
        functionRef = {
            name = "crossplane-contrib-function-kcl"
        }
        input = func.KCLInput {
            metadata = v1.ObjectMeta {
                name = _slug
            }
            spec = {
                source = file.read(filepath)
                target = "Resources"
                dependencies = DEPENDENCIES
            }
        }
    }
}

xrd = crd.CompositeResourceDefinition {
    metadata.name = "${PLURAL}.${GROUP}"
    spec = {
        group = GROUP
        names = {
            kind = KIND
            plural = PLURAL
        }
        versions = [{
            name = "v1alpha1"
            served = True
            referenceable = True
            schema.openAPIV3Schema = {type = "object"}
        }]
    }
}

comp = compdef.Composition {
    metadata.name = COMPOSITION_NAME
    spec = {
        compositeTypeRef = {
            apiVersion = "${GROUP}/v1alpha1"
            kind = KIND
        }
        mode = "Pipeline"
        pipeline = [
            generate_function_meta("functions/droplet.k", globalvars.steps.droplet)
            generate_function_meta("functions/image.k", globalvars.steps.image)
            generate_function_meta("functions/dns.k", globalvars.steps.dns)
        ]
    }
}

xr = {
    apiVersion = "${GROUP}/v1alpha1"
    kind = KIND
    metadata = {name = XR_NAME}
    spec = {
        compositionRef.name = COMPOSITION_NAME
    }
}

manifests.yaml_stream([xrd, comp, xr])
