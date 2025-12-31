from typing import Any, List, Mapping, Sequence, Type, TypeVar, Union, cast

import yaml
from cloudcoil import apimachinery
from cloudcoil.models.kubernetes.apps.v1 import Deployment
from cloudcoil.models.kubernetes.core.v1 import Service
from cloudcoil.resources import Resource, Unstructured

T = TypeVar("T", bound=Resource)


def parse_kcl_yaml(yaml_text: str) -> List[Resource]:
    objs: List[Resource] = []

    for raw_doc in yaml.safe_load_all(yaml_text):
        if not isinstance(raw_doc, dict):
            continue

        try:
            obj = Unstructured.model_validate(raw_doc)
            objs.append(obj)
        except Exception:
            continue

    return objs


def is_partial_match(struct: Mapping[str, Any], partial: Mapping[str, Any]) -> bool:
    """
    Checks whether `partial` is a subset of `struct`.
    - Exact match for primitive values and lists.
    - Recursively matches nested dictionaries.
    """
    for key, partial_value in partial.items():
        if key not in struct:
            return False

        struct_value = struct[key]

        if isinstance(partial_value, dict):
            if not isinstance(struct_value, dict):
                return False
            # Explicitly cast for Pyright
            if not is_partial_match(
                cast(Mapping[str, Any], struct_value),
                cast(Mapping[str, Any], partial_value),
            ):
                return False

        elif isinstance(partial_value, list):
            if not isinstance(struct_value, list):
                return False
            if struct_value != partial_value:
                return False

        else:
            if struct_value != partial_value:
                return False

    return True


def find_first_of_type(
    resources: Sequence[Resource],
    match: Union[Type[T], T],
    match_partial: bool = True,
) -> T:
    is_partial = not isinstance(match, type)
    typ: Type[T] = match if isinstance(match, type) else type(match)

    for res in resources:
        try:
            res_data = res.model_dump(exclude_none=True, exclude_unset=True)
            typed_res = typ.model_validate(res_data)
        except Exception:
            continue

        if is_partial and match_partial:
            res_dict = typed_res.model_dump(exclude_none=True, exclude_unset=True)
            partial_dict = match.model_dump(exclude_none=True, exclude_unset=True)  # type: ignore
            if not is_partial_match(res_dict, partial_dict):
                continue

        return typed_res

    raise ValueError(f"Type {typ} with matching spec not found in resources")


# --- usage ---
if __name__ == "__main__":
    import textwrap

    yaml_input = textwrap.dedent("""
        api_version: apps/v1
        kind: Deployment
        metadata:
          name: nginx
        spec:
          replicas: 2
          selector:
            match_labels:
              app: nginx
          template:
            metadata:
              labels:
                app: nginx
            spec:
              containers:
              - name: nginx
                image: nginx:latest
                ports:
                - container_port: 80
        ---
        api_version: v1
        kind: Service
        metadata:
          name: nginx-svc
        spec:
          selector:
            app: nginx
          ports:
          - port: 80
            target_port: 80
        ---
        api_version: v1
        kind: Service
        metadata:
          name: other-svc
        spec:
          selector:
            app: other-app
          ports:
          - port: 8080
            target_port: 8080
    """)

    resources = parse_kcl_yaml(yaml_input)

    deployment: Deployment = find_first_of_type(resources, Deployment)

    service: Service = find_first_of_type(
        resources, Service(metadata=apimachinery.ObjectMeta(name="other-svc"))
    )

    # print("Service metadata:", service.metadata)
    print(yaml.dump(service.model_dump(exclude_none=True, exclude_unset=True)))
