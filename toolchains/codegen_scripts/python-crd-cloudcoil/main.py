import re
import shutil
import sys
from importlib.resources import as_file, files
from pathlib import Path
from typing import List

import typer
from cloudcoil.codegen.generator import ModelConfig, Transformation, generate

app = typer.Typer()

ROOT = Path(__file__).parent
TEMPLATE_DIR = ROOT / "templates"


def build_model_config(
    namespace: str, inputs: List[str], output_dir: Path
) -> ModelConfig:
    return ModelConfig(
        namespace=namespace,
        input_=inputs,
        output=output_dir,
        mode="resource",
        log_level="INFO",
        transformations=[
            Transformation(
                match_=re.compile(
                    r"^io\.k8s\.apimachinery\.pkg\.apis\.meta\.v1\.ObjectMeta$"
                ),
                replace="apimachinery.ObjectMeta",
                namespace="cloudcoil",
            )
        ],
        additional_datamodel_codegen_args=[
            "--custom-template-dir",
            str(TEMPLATE_DIR.absolute()),
        ],
        generate_init=True,
        generate_py_typed=True,
    )


def clean_output_dir(output: Path, clean: bool):
    if clean and output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True, exist_ok=True)


@app.command()
def main(
    namespace: str = typer.Argument(...),
    input: List[str] = typer.Option(..., "--input", "-i"),
    output: Path = typer.Option(..., "--output", "-o"),
    clean: bool = typer.Option(False, "--clean"),
):
    clean_output_dir(output, clean)

    config = build_model_config(namespace, input, output)
    try:
        generate(config)
    except Exception as e:
        raise SystemExit(1)


if __name__ == "__main__":
    app()
