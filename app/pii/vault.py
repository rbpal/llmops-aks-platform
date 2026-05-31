"""Token -> real PII vault (step_02_task02).

Primary backend = Azure Key Vault (decision); local encrypted file (Fernet) is the
offline inner-loop fallback. Selected by VAULT_BACKEND. The key for the local file
lives next to it (data/vault/, gitignored); prod uses Key Vault + workload identity.
"""
from __future__ import annotations

import json
import re
from pathlib import Path

from app.config import settings


class VaultBackend:
    def put(self, token: str, value: str) -> None: ...
    def get(self, token: str) -> str | None: ...


class LocalVault(VaultBackend):
    def __init__(self) -> None:
        from cryptography.fernet import Fernet

        self.path = Path(settings.vault_path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        keypath = self.path.parent / "vault.key"
        if keypath.exists():
            key = keypath.read_bytes()
        else:
            key = Fernet.generate_key()
            keypath.write_bytes(key)
        self._fernet = Fernet(key)
        self._data: dict[str, str] = (
            json.loads(self.path.read_text()) if self.path.exists() else {}
        )

    def put(self, token: str, value: str) -> None:
        self._data[token] = self._fernet.encrypt(value.encode()).decode()
        self.path.write_text(json.dumps(self._data))

    def get(self, token: str) -> str | None:
        enc = self._data.get(token)
        return self._fernet.decrypt(enc.encode()).decode() if enc else None


class KeyVaultBackend(VaultBackend):
    def __init__(self) -> None:
        from azure.identity import DefaultAzureCredential
        from azure.keyvault.secrets import SecretClient

        self._c = SecretClient(
            vault_url=settings.key_vault_uri,
            credential=DefaultAzureCredential(),
        )

    @staticmethod
    def _name(token: str) -> str:
        # KV secret names allow only [0-9a-zA-Z-]
        return "pii-" + re.sub(r"[^0-9a-zA-Z-]", "-", token).strip("-")

    def put(self, token: str, value: str) -> None:
        self._c.set_secret(self._name(token), value)

    def get(self, token: str) -> str | None:
        try:
            return self._c.get_secret(self._name(token)).value
        except Exception:
            return None


def get_vault() -> VaultBackend:
    return KeyVaultBackend() if settings.vault_backend == "key_vault" else LocalVault()
