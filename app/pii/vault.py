"""Token -> real PII vault. Primary backend = Azure Key Vault (project decision);
local encrypted file is the offline fallback.

TODO(step_02_task02): LocalVault round-trip; KeyVaultBackend via DefaultAzureCredential.
"""
from __future__ import annotations

from app.config import settings


class VaultBackend:
    def put(self, token: str, value: str) -> None: ...
    def get(self, token: str) -> str | None: ...


class LocalVault(VaultBackend):
    pass  # TODO(step_02_task02): encrypted/obfuscated file at settings.vault_path


class KeyVaultBackend(VaultBackend):
    pass  # TODO(step_02_task02): azure-keyvault-secrets + DefaultAzureCredential


def get_vault() -> VaultBackend:
    return KeyVaultBackend() if settings.vault_backend == "key_vault" else LocalVault()
