import schemas.kcl.digitalocean_kcl.models.v1alpha1.dns_digitalocean_crossplane_io_v1alpha1_domain as do_domain
import schemas.kcl.digitalocean_kcl.models.v1alpha1.dns_digitalocean_crossplane_io_v1alpha1_record as do_record
import schemas.kcl.digitalocean_kcl.models.v1alpha1.droplet_digitalocean_crossplane_io_v1alpha1_droplet as do_droplet
import k8s.apimachinery.pkg.apis.meta.v1 as meta
import configurations.common.kclrun_helpers as h
import manifests

DOMAIN = "becker63.cloud"

_ocds = option("params").ocds
droplet_res: do_droplet.Droplet = _ocds[globalvars.steps.droplet]?.Resource

droplet_ip_raw = droplet_res?.status?.atProvider?.ipv4Address
maybe_droplet_ip = droplet_ip_raw if h.is_defined(droplet_ip_raw) else None

_out: [do_domain.Domain | do_record.Record | [any]] = []

if maybe_droplet_ip:
    _domain = do_domain.Domain {
        metadata = meta.ObjectMeta {name = "droplet-domain-name"}
        spec = {
            forProvider = {
                name = DOMAIN
                ipAddress = maybe_droplet_ip
            }
            providerConfigRef = {name = "default"}
        }
    }

    _frps = do_record.Record {
        metadata = meta.ObjectMeta {name = "frps-record"}
        spec = {
            forProvider = {
                name = "frps"
                domain = DOMAIN
                $type = "A"
                ttl = 300
                value = maybe_droplet_ip
            }
            providerConfigRef = {name = "default"}
        }
    }

    _headlamp = do_record.Record {
        metadata = meta.ObjectMeta {name = "headlamp-record"}
        spec = {
            forProvider = {
                name = "headlamp"
                domain = DOMAIN
                $type = "A"
                ttl = 300
                value = maybe_droplet_ip
            }
            providerConfigRef = {name = "default"}
        }
    }

    _out = [_domain, _frps, _headlamp]

# Emit whatever we built (empty list when IP isn’t ready yet)
manifests.yaml_stream(_out)
