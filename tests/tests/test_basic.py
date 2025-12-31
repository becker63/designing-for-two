from generated.fluxcd_helm.fluxcd_helm.io.fluxcd.toolkit.helm.v2 import HelmRelease

from src.lib.lib import test


def test_basic(dummy):
    print("Contents of instantiated generated helmrelease: ")
    print(HelmRelease)

    test("")
    assert dummy == "hello from fixture"
