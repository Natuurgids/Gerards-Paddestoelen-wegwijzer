#!/usr/bin/env python3
"""Build deployable paid-learning packages from private source JSON.

Commercial lesson bodies must stay outside this public repository. This tool reads
one private package JSON per public offering, validates the package/training
contract, canonicalizes the package bytes, computes immutable SHA-256/size
metadata, and atomically emits a catalogue plus packages for controlled hosting.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import tempfile
from pathlib import Path
from typing import Any

LANGUAGES = ("nl", "en", "de")
PRICE_FIELDS = {
    "price",
    "price_amount",
    "display_price",
    "currency",
    "currency_code",
}
DOWNLOADABLE_LESSON_ID_FLOOR = 1000


def _load_object(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ValueError(f"Invalid JSON file {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise ValueError(f"JSON root must be an object: {path}")
    return value


def _required_string(value: Any, context: str) -> str:
    if not isinstance(value, str) or not value or value.strip() != value:
        raise ValueError(f"{context} must be a trimmed non-empty string")
    return value


def _required_positive_int(value: Any, context: str) -> int:
    if not isinstance(value, int) or isinstance(value, bool) or value <= 0:
        raise ValueError(f"{context} must be a positive integer")
    return value


def _reject_price_fields(value: Any, context: str = "package") -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            if key in PRICE_FIELDS:
                raise ValueError(f"{context} must not contain store pricing field {key}")
            _reject_price_fields(child, context)
    elif isinstance(value, list):
        for child in value:
            _reject_price_fields(child, context)


def _validate_localized_objects(value: Any, fields: tuple[str, ...], context: str) -> None:
    if not isinstance(value, dict) or any(language not in value for language in LANGUAGES):
        raise ValueError(f"{context} must contain nl, en and de")
    for language in LANGUAGES:
        item = value[language]
        if not isinstance(item, dict):
            raise ValueError(f"{context} has invalid {language} object")
        for field in fields:
            text = item.get(field)
            if not isinstance(text, str) or not text.strip():
                raise ValueError(f"{context} has invalid {language} {field}")


def _validate_labels(value: Any, context: str) -> None:
    if not isinstance(value, dict) or any(language not in value for language in LANGUAGES):
        raise ValueError(f"{context} must contain nl, en and de labels")
    for language in LANGUAGES:
        label = value[language]
        if not isinstance(label, str) or not label.strip():
            raise ValueError(f"{context} has invalid {language} label")


def load_offerings(path: Path, expected_count: int | None) -> list[dict[str, Any]]:
    root = _load_object(path)
    if root.get("catalog_version") != 1:
        raise ValueError("Public learning offerings catalog_version must be 1")
    raw = root.get("offerings")
    if not isinstance(raw, list) or not raw:
        raise ValueError("Public learning offerings must be a non-empty list")
    if expected_count is not None and len(raw) != expected_count:
        raise ValueError(
            f"Expected {expected_count} public learning offerings, found {len(raw)}"
        )

    offerings: list[dict[str, Any]] = []
    unique_fields = {
        "package_key": set(),
        "course_key": set(),
        "entitlement_key": set(),
        "product_key": set(),
    }
    for index, value in enumerate(raw):
        if not isinstance(value, dict):
            raise ValueError(f"Offering {index} must be an object")
        offering = dict(value)
        for field, seen in unique_fields.items():
            key = _required_string(offering.get(field), f"offering {index} {field}")
            if key in seen:
                raise ValueError(f"Duplicate public offering {field}: {key}")
            seen.add(key)
        _required_string(offering.get("group_key"), f"offering {index} group_key")
        if not isinstance(offering.get("sort_order"), int):
            raise ValueError(f"offering {index} sort_order must be an integer")
        _validate_localized_objects(
            offering.get("texts"), ("title", "summary"), f"offering {index} texts"
        )
        offerings.append(offering)
    return offerings


def validate_package(package: dict[str, Any], offering: dict[str, Any]) -> None:
    package_key = offering["package_key"]
    if package.get("package_version") != 1:
        raise ValueError(f"{package_key}: package_version must be 1")
    if package.get("package_key") != package_key:
        raise ValueError(f"{package_key}: package_key does not match public offering")
    _required_positive_int(package.get("content_version"), f"{package_key} content_version")
    _reject_price_fields(package, package_key)

    course = package.get("course")
    if not isinstance(course, dict):
        raise ValueError(f"{package_key}: course must be an object")
    expected_course = {
        "key": offering["course_key"],
        "access": "entitlement_required",
        "delivery": "downloadable",
        "entitlement_key": offering["entitlement_key"],
        "product_key": offering["product_key"],
        "group_key": offering["group_key"],
        "sort_order": offering["sort_order"],
    }
    for field, expected in expected_course.items():
        if course.get(field) != expected:
            raise ValueError(
                f"{package_key}: course {field} must match public offering ({expected!r})"
            )

    modules = package.get("modules")
    if not isinstance(modules, list) or not modules:
        raise ValueError(f"{package_key}: modules must be a non-empty list")
    module_keys: set[str] = set()
    assigned_lessons: set[int] = set()
    for module in modules:
        if not isinstance(module, dict):
            raise ValueError(f"{package_key}: module must be an object")
        key = _required_string(module.get("key"), f"{package_key} module key")
        if key in module_keys:
            raise ValueError(f"{package_key}: duplicate module key {key}")
        module_keys.add(key)
        if module.get("course_key") != offering["course_key"]:
            raise ValueError(f"{package_key}: module {key} references wrong course")
        lesson_ids = module.get("lesson_ids")
        if not isinstance(lesson_ids, list) or not lesson_ids:
            raise ValueError(f"{package_key}: module {key} must declare lesson_ids")
        for lesson_id in lesson_ids:
            if (
                not isinstance(lesson_id, int)
                or isinstance(lesson_id, bool)
                or lesson_id < DOWNLOADABLE_LESSON_ID_FLOOR
                or lesson_id in assigned_lessons
            ):
                raise ValueError(f"{package_key}: invalid/duplicate lesson id {lesson_id}")
            assigned_lessons.add(lesson_id)

    for module in modules:
        prerequisites = module.get("prerequisite_module_keys", [])
        if not isinstance(prerequisites, list):
            raise ValueError(f"{package_key}: module prerequisites must be a list")
        key = module["key"]
        for prerequisite in prerequisites:
            if prerequisite == key or prerequisite not in module_keys:
                raise ValueError(
                    f"{package_key}: module {key} has invalid prerequisite {prerequisite}"
                )

    training = package.get("training_content")
    if not isinstance(training, dict) or training.get("version") != 2:
        raise ValueError(f"{package_key}: training_content version must be 2")
    lessons = training.get("lessons")
    if not isinstance(lessons, list) or not lessons:
        raise ValueError(f"{package_key}: training_content lessons must be non-empty")

    lesson_ids: set[int] = set()
    lesson_slugs: set[str] = set()
    question_ids: set[int] = set()
    answer_ids: set[int] = set()
    for lesson in lessons:
        if not isinstance(lesson, dict):
            raise ValueError(f"{package_key}: lesson must be an object")
        lesson_id = lesson.get("id")
        if (
            not isinstance(lesson_id, int)
            or isinstance(lesson_id, bool)
            or lesson_id < DOWNLOADABLE_LESSON_ID_FLOOR
            or lesson_id in lesson_ids
        ):
            raise ValueError(f"{package_key}: invalid/duplicate lesson id {lesson_id}")
        lesson_ids.add(lesson_id)
        slug = _required_string(lesson.get("slug"), f"{package_key} lesson {lesson_id} slug")
        if slug in lesson_slugs:
            raise ValueError(f"{package_key}: duplicate lesson slug {slug}")
        lesson_slugs.add(slug)
        _validate_localized_objects(
            lesson.get("texts"), ("title", "body"), f"{package_key} lesson {lesson_id}"
        )
        questions = lesson.get("questions")
        if not isinstance(questions, list):
            raise ValueError(f"{package_key}: lesson {lesson_id} must declare questions")
        for question in questions:
            if not isinstance(question, dict):
                raise ValueError(f"{package_key}: question must be an object")
            question_id = question.get("id")
            if (
                not isinstance(question_id, int)
                or isinstance(question_id, bool)
                or question_id in question_ids
            ):
                raise ValueError(f"{package_key}: invalid/duplicate question id {question_id}")
            question_ids.add(question_id)
            _validate_localized_objects(
                question.get("texts"), ("prompt",), f"{package_key} question {question_id}"
            )
            answers = question.get("answers")
            if not isinstance(answers, list) or len(answers) < 2:
                raise ValueError(
                    f"{package_key}: question {question_id} needs at least two answers"
                )
            correct_count = 0
            for answer in answers:
                if not isinstance(answer, dict):
                    raise ValueError(f"{package_key}: answer must be an object")
                answer_id = answer.get("id")
                if (
                    not isinstance(answer_id, int)
                    or isinstance(answer_id, bool)
                    or answer_id in answer_ids
                ):
                    raise ValueError(
                        f"{package_key}: invalid/duplicate answer id {answer_id}"
                    )
                answer_ids.add(answer_id)
                _validate_labels(
                    answer.get("labels"), f"{package_key} answer {answer_id}"
                )
                if answer.get("correct") is True:
                    correct_count += 1
            if correct_count != 1:
                raise ValueError(
                    f"{package_key}: question {question_id} must have exactly one correct answer"
                )

    if lesson_ids != assigned_lessons:
        raise ValueError(
            f"{package_key}: module lesson ids must exactly match training lesson ids"
        )


def _canonical_bytes(value: dict[str, Any]) -> bytes:
    return (
        json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
        + "\n"
    ).encode("utf-8")


def _is_within(path: Path, root: Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except ValueError:
        return False


def publish(
    *,
    source_dir: Path,
    output_dir: Path,
    offerings_path: Path,
    expected_count: int | None = 7,
) -> dict[str, Any]:
    repo_root = Path(__file__).resolve().parents[1]
    source_dir = source_dir.resolve()
    output_dir = output_dir.resolve()
    if _is_within(source_dir, repo_root):
        raise ValueError("Private paid-learning source directory must be outside this public repository")
    if _is_within(output_dir, repo_root):
        raise ValueError("Paid-learning publish output must be outside this public repository")
    if source_dir == output_dir:
        raise ValueError("Source and output directories must be different")
    if not source_dir.is_dir():
        raise ValueError(f"Private source directory does not exist: {source_dir}")
    if output_dir.exists():
        raise ValueError(f"Publish output already exists: {output_dir}")

    offerings = load_offerings(offerings_path, expected_count)
    expected_names = {f"{offering['package_key']}.json" for offering in offerings}
    actual_names = {path.name for path in source_dir.glob("*.json")}
    missing = sorted(expected_names - actual_names)
    extra = sorted(actual_names - expected_names)
    if missing or extra:
        raise ValueError(f"Private package file set mismatch; missing={missing}, extra={extra}")

    output_parent = output_dir.parent
    output_parent.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix=f".{output_dir.name}-", dir=output_parent))
    try:
        packages_dir = staging / "packages"
        packages_dir.mkdir()
        descriptors: list[dict[str, Any]] = []
        for offering in offerings:
            package_key = offering["package_key"]
            package = _load_object(source_dir / f"{package_key}.json")
            validate_package(package, offering)
            payload = _canonical_bytes(package)
            package_name = f"{package_key}.json"
            (packages_dir / package_name).write_bytes(payload)
            descriptors.append(
                {
                    "package_key": package_key,
                    "course_key": offering["course_key"],
                    "entitlement_key": offering["entitlement_key"],
                    "product_key": offering["product_key"],
                    "content_version": package["content_version"],
                    "package_path": f"packages/{package_name}",
                    "package_sha256": hashlib.sha256(payload).hexdigest(),
                    "package_size_bytes": len(payload),
                    "sort_order": offering["sort_order"],
                    "texts": offering["texts"],
                }
            )

        descriptors.sort(key=lambda item: item["sort_order"])
        catalog = {"catalog_version": 1, "packages": descriptors}
        (staging / "learning_package_catalog.json").write_bytes(
            _canonical_bytes(catalog)
        )
        os.replace(staging, output_dir)
        return catalog
    except BaseException:
        shutil.rmtree(staging, ignore_errors=True)
        raise


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Build controlled-hosting artifacts from private paid-learning sources"
    )
    parser.add_argument("--source-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument(
        "--offerings",
        type=Path,
        default=Path("assets/data/learning_offerings.json"),
    )
    parser.add_argument("--expected-count", type=int, default=7)
    args = parser.parse_args()
    catalog = publish(
        source_dir=args.source_dir,
        output_dir=args.output_dir,
        offerings_path=args.offerings,
        expected_count=args.expected_count,
    )
    print(
        f"Published {len(catalog['packages'])} learning packages to {args.output_dir}"
    )


if __name__ == "__main__":
    main()
