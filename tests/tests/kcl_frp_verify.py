import subprocess
from pathlib import Path

from lib.kcl_ext import Exec
from lib.test_ext import KFile, make_kcl_named_test


def run_frp_verify(name: str, kf: KFile, tmp_path: Path) -> None:
    config_path = tmp_path / f"{name}.json"
    config_path.write_text(Exec(kf.path).json_result)

    completed = subprocess.run(
        [name, "verify", f"--config={config_path}"], capture_output=True, check=False
    )

    assert completed.returncode == 0, (
        f"{name} verify failed\n"
        f"stdout: {completed.stdout.decode()}\n"
        f"stderr: {completed.stderr.decode()}"
    )


@make_kcl_named_test(
    ["FRPC_Config.k", "FRPS_Config.k"],
    lambda kf: (kf.path.name in {"FRPC_Config.k", "FRPS_Config.k"}),
)
def check_frp_validate(
    clientconfig_kf: KFile, serverconfig_kf: KFile, tmp_path: Path
) -> None:
    run_frp_verify("frpc", clientconfig_kf, tmp_path)
    run_frp_verify("frps", serverconfig_kf, tmp_path)
