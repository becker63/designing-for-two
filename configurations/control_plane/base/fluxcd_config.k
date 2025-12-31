import k8s.apimachinery.pkg.apis.meta.v1 as meta
import schemas.kcl.flux_kcl_controller_kcl.models.v1.source_toolkit_fluxcd_io_v1_git_repository as fluxcd

fluxcd.GitRepository {
    metadata = meta.ObjectMeta {
        name = "static-control-plane"
        namespace = "flux-system"
    }
    spec = {
        url = "https://github.com/becker63/static-control-plane"
        interval = "1m"
        ref = {
            branch = "main"
        }
    }
}
