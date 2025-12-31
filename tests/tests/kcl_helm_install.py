import json
import subprocess

from cloudcoil.errors import ResourceNotFound
from cloudcoil.models.kubernetes.core.v1 import Namespace

from lib.kcl_ext import Exec
from lib.test_ext import KFile, make_kcl_named_test
from tests.generated.fluxcd_helm_controller.fluxcd_helm_controller.io.fluxcd.toolkit.helm.v2 import (
    HelmRelease,
)


# TODO: cover all files eventually
@make_kcl_named_test(
    ["crossplane_release.k"], lambda kf: "helm_releases" in kf.path.parts
)
def e2e_frp_kuttl(crossplane_release: KFile) -> None:
    # Run flux sync
    subprocess.run(
        ["flux", "run"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )

    # Parse HelmRelease from KCL output
    result = Exec(crossplane_release.path).json_result
    release = HelmRelease.model_validate(json.loads(result))
    metadata = release.metadata

    # Check required metadata fields
    if not metadata or not metadata.namespace or not metadata.name:
        raise ValueError("HelmRelease.metadata.namespace and name are required")

    namespace_name = metadata.namespace
    release_name = metadata.name

    # Ensure namespace exists
    try:
        Namespace.get(name=namespace_name)
        print(f"Namespace '{namespace_name}' already exists.")
    except ResourceNotFound:
        ns = (
            Namespace.builder()
            .metadata(lambda m: m.name(namespace_name))
            .build()
            .create()
        )
        for event, _ in ns.watch():
            if event == "ADDED":
                print(f"Namespace '{namespace_name}' created.")
                break

    # Ensure HelmRelease exists
    try:
        HelmRelease.get(name=release_name, namespace=namespace_name)
        print(f"HelmRelease '{release_name}' already exists.")
    except ResourceNotFound:
        for event, _ in release.create().watch(namespace=namespace_name):
            if event == "ADDED":
                print(f"HelmRelease '{release_name}' created.")
                break
