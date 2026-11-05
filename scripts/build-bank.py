#!/usr/bin/env python3
"""data/bank/<場面>.txt（1 行 = 日本語|英語|丁寧|くだけた|単語=意味;単語=意味）から App/Resources/PhraseBank.json を作る。
単語（英語）は英文の中にそのまま現れること。違えば止まる。使い方: python3 scripts/build-bank.py
"""
import json
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(__file__), "..")
ORDER = ["work", "travel", "daily", "feelings", "shop", "social"]


def norm(s: str) -> str:
    return re.sub(r"[^a-z0-9' -]", "", s.lower().replace("’", "'"))


def main() -> int:
    out, seen, errors = [], set(), []
    for scene in ORDER:
        path = os.path.join(ROOT, "data", "bank", f"{scene}.txt")
        with open(path, encoding="utf-8") as f:
            for i, line in enumerate(f, 1):
                parts = line.rstrip("\n").split("|")
                if len(parts) != 5:
                    errors.append(f"{scene}:{i} 欄の数が 5 でない")
                    continue
                ja, en, polite, casual, words = parts
                if ja in seen:
                    errors.append(f"{scene}:{i} 日本語が重複: {ja}")
                seen.add(ja)
                items = []
                for w in words.split(";"):
                    e, _, j = w.partition("=")
                    if not e.strip() or not j.strip() or norm(e) not in norm(en):
                        errors.append(f"{scene}:{i} 単語が英文にない: {w}")
                    items.append({"en": e, "ja": j})
                out.append({"id": f"{scene}-{i:03d}", "scene": scene, "ja": ja, "en": en,
                            "polite": polite, "casual": casual, "words": items})
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    doc = ("手で用意したフレーズの束（2026-11-05）。scene: work 職場 / travel 旅行 / daily 日常 / feelings 気持ち / "
           "shop お店・レストラン / social 人づきあい。words の en は en の中にそのまま現れる（テストで確かめる）。")
    with open(os.path.join(ROOT, "App", "Resources", "PhraseBank.json"), "w", encoding="utf-8") as f:
        json.dump({"_doc": doc, "version": 1, "phrases": out}, f, ensure_ascii=False, indent=1)
    print(f"{len(out)} 件")
    return 0


if __name__ == "__main__":
    sys.exit(main())
