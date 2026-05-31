from app.registry import loader


def test_load_answer_generation():
    p = loader.load("answer_generation")
    assert p.name == "answer_generation"
    assert p.version == 1
    assert "{context}" in p.template and "{question}" in p.template
    assert p.git_sha  # records some sha (or 'nogit')
