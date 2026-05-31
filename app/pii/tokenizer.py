"""Deterministic PII tokenizer: SSN/account -> [SSN_xxxx]/[ACCT_xxxx].

TODO(step_02_task01): same value -> same token (deterministic).
"""


def tokenize(text: str) -> str:
    raise NotImplementedError  # TODO(step_02_task01)


def detokenize(text: str) -> str:
    raise NotImplementedError  # TODO(step_02_task04): authorization-gated
