"""스낵용 strict JSON Schema와 원문 없는 검증 진단."""


DOMAIN_MESSAGES = {
    "Value error, Identity language does not match content language.",
    "Value error, Usage identity requires a contrast.",
    "Value error, Homonyms require pronunciation and its standard.",
    "Value error, Explanations must use the other supported language.",
    "Value error, Register identity requires context and registers.",
    "Value error, Unrelated entry fields.",
    "Value error, Identity relation does not match content type.",
    "Value error, Identity entry count does not match content type.",
    "Value error, Payload headword does not match identity.",
    "Value error, Collocations require a headword.",
    "Value error, Regional entries require variety codes.",
    "Value error, New identity fields are not valid for legacy types.",
    "Value error, Payload expressions do not match the reserved identity.",
    "Value error, Unrelated identity fields.",
}


def strict_schema(model):
    schema = model.model_json_schema()

    def visit(node):
        if isinstance(node, list):
            for item in node:
                visit(item)
        elif isinstance(node, dict):
            node.pop("default", None)
            if "const" in node:
                node["enum"] = [node.pop("const")]
            if node.get("type") == "object":
                node["additionalProperties"] = False
                node["required"] = list(node.get("properties", {}))
            for value in node.values():
                visit(value)

    visit(schema)
    return schema


def validation_issues(error, schema):
    # 추가 필드명에도 모델 출력이 들어갈 수 있어 알려진 스키마 키만 기록해요.
    fields = set()

    def collect(node):
        if isinstance(node, dict):
            fields.update(node.get("properties", {}))
            for value in node.values():
                collect(value)
        elif isinstance(node, list):
            for value in node:
                collect(value)

    collect(schema)
    return [
        {
            "type": item["type"],
            **({"reason": item["msg"]} if item["msg"] in DOMAIN_MESSAGES else {}),
            "loc": [
                part if isinstance(part, int) or part in fields else "<extra>"
                for part in item["loc"]
            ],
        }
        for item in error.errors(
            include_url=False, include_context=False, include_input=False
        )[:10]
    ]


# 생성 요청에서는 해당 유형의 지식을 설명하는 필드만 허용해요.
CANDIDATE_FIELDS = {
    "regional_variant": ("regional_equivalent", [], ["variety"]),
    "usage_contrast": ("usage_difference", ["contrast"], []),
    "homonym": ("same_sound", ["pronunciation", "pronunciation_standard"], []),
    "register_contrast": ("register_difference", ["context"], ["register"]),
    "collocation": ("collocation_set", ["headword"], []),
    "idiomatic_expression": ("idiomatic_meaning", [], []),
}


def candidate_schema(model, kind, language, count):
    schema = strict_schema(model)
    relation, identity_fields, entry_fields = CANDIDATE_FIELDS[kind]
    definitions = schema["$defs"]
    candidate = definitions["Candidate"]["properties"]
    candidate["content_type"]["enum"] = [kind]
    candidate["content_language"]["enum"] = [language]
    for name, allowed in [
        ("KnowledgeIdentity", ["relation", "entries", *identity_fields]),
        ("IdentityEntry", ["language", "expression", "sense", *entry_fields]),
    ]:
        node = definitions[name]
        node["properties"] = {
            key: value for key, value in node["properties"].items() if key in allowed
        }
        node["required"] = list(node["properties"])
        for key, value in node["properties"].items():
            if "anyOf" in value:
                node["properties"][key] = next(
                    branch for branch in value["anyOf"] if branch.get("type") != "null"
                )
    identity = definitions["KnowledgeIdentity"]["properties"]
    identity["relation"]["enum"] = [relation]
    identity["entries"]["minItems"] = identity["entries"]["maxItems"] = (
        1 if kind == "idiomatic_expression" else 2
    )
    definitions["IdentityEntry"]["properties"]["language"]["enum"] = [language]
    schema["properties"]["candidates"]["maxItems"] = count
    return schema
