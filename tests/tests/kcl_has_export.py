from lib.test_ext import KFile, make_kcl_test


@make_kcl_test(lambda kf: "base" in kf.path.parts)
def check_has_export(kf: KFile) -> None:
    content = kf.path.read_text()
    assert "manifests.yaml_stream(" in content, (
        f'\n\nmust include "manifests.yaml_stream" and must export something for consistency: {kf.path}\n\n'
    )
