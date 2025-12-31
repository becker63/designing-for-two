import regex
import k8s.apimachinery.pkg.apis.meta.v1 as meta
import schemas.kcl.infisical_kcl.models.v1alpha1.secrets_infisical_com_v1alpha1_infisical_secret as infisical

schema InfisicalSecret:
    slug: str
    keys: {str:str}

    namespace: str = "default"
    envSlug: str = "prod"
    tokenSecretName: str = "infisical-token"
    tokenSecretNamespace: str = "default"

    # Sanitize slug to use as base path component: lowercase, hyphenated, alphanumeric only
    basePath: str = "/" + regex.replace(slug, "[^a-zA-Z0-9_-]", "-")

    secretsPath: str = basePath

    secret: infisical.InfisicalSecret = {
        metadata = meta.ObjectMeta {
            name = slug
            namespace = namespace
        }
        spec = {
            resyncInterval = 60
            authentication = {
                serviceToken = {
                    serviceTokenSecretReference = {
                        secretName = tokenSecretName
                        secretNamespace = tokenSecretNamespace
                    }
                    secretsScope = {
                        envSlug = envSlug
                        secretsPath = secretsPath
                        recursive = False
                    }
                }
            }
            managedKubeSecretReferences = [{
                secretName = slug
                secretNamespace = namespace
                creationPolicy = "Orphan"
                secretType = "Opaque"
                template = {
                    includeAllSecrets = False
                    data = {keys[k]: "{{ ." + k + ".Value }}" for k in keys}
                }
            }]
        }
    }

