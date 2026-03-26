#!/usr/bin/env python3
"""
helix-vector.py — Motor de memoria semántica de Helix
Uso:
  helix-vector.py store <collection> <text> [--id ID] [--meta KEY=VALUE ...]
  helix-vector.py search <collection> <query> [--top-k 5] [--threshold 0.6]
  helix-vector.py index-dir <directory> <collection> [--pattern *.md]
  helix-vector.py index-memories
  helix-vector.py index-agents
  helix-vector.py list-collections
  helix-vector.py delete <collection> <id>
"""

import sys
import os
import json
import argparse
import hashlib
from pathlib import Path
from datetime import datetime

import requests
from qdrant_client import QdrantClient
from qdrant_client.models import (
    Distance, VectorParams, PointStruct, Filter,
    FieldCondition, MatchValue, UpdateStatus, Query
)

QDRANT_URL = os.environ.get("QDRANT_URL", "http://localhost:6333")
OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://localhost:11434")
EMBED_MODEL = os.environ.get("HELIX_EMBED_MODEL", "nomic-embed-text")
VECTOR_SIZE = 768  # nomic-embed-text output size

client = QdrantClient(url=QDRANT_URL)


def translate_to_english(text: str) -> str:
    """Translate text to English using Ollama for better embedding quality."""
    resp = requests.post(
        f"{OLLAMA_URL}/api/generate",
        json={
            "model": "llama3.2:3b",
            "prompt": f"You are a software developer. Translate this developer task/question to English. Respond with ONLY the English translation:\n{text}\n\nEnglish:",
            "stream": False,
            "options": {"temperature": 0, "num_predict": 80, "stop": ["\n\n", "Here", "Note"]}
        },
        timeout=60
    )
    if resp.status_code == 200:
        return resp.json().get("response", text).strip()
    return text


def embed(text: str, translate: bool = False) -> list[float]:
    """Generate embedding via Ollama. Optionally translate to English first."""
    if translate:
        text = translate_to_english(text)
    resp = requests.post(
        f"{OLLAMA_URL}/api/embeddings",
        json={"model": EMBED_MODEL, "prompt": text},
        timeout=30
    )
    resp.raise_for_status()
    return resp.json()["embedding"]


def ensure_collection(collection: str):
    """Create collection if it doesn't exist."""
    existing = [c.name for c in client.get_collections().collections]
    if collection not in existing:
        client.create_collection(
            collection_name=collection,
            vectors_config=VectorParams(size=VECTOR_SIZE, distance=Distance.COSINE)
        )


def text_to_id(text: str) -> str:
    """Stable ID from content hash (first 16 hex chars as UUID-like)."""
    h = hashlib.md5(text.encode()).hexdigest()
    return f"{h[:8]}-{h[8:12]}-{h[12:16]}-{h[16:20]}-{h[20:32]}"


def cmd_store(args):
    collection = args.collection
    text = args.text
    meta = {}
    if args.meta:
        for kv in args.meta:
            k, v = kv.split("=", 1)
            meta[k] = v
    meta["text"] = text
    meta["indexed_at"] = datetime.utcnow().isoformat()

    point_id = args.id if args.id else text_to_id(text)

    ensure_collection(collection)
    vector = embed(text)
    client.upsert(
        collection_name=collection,
        points=[PointStruct(id=point_id, vector=vector, payload=meta)]
    )
    print(json.dumps({"status": "ok", "id": point_id, "collection": collection}))


def cmd_search(args):
    collection = args.collection
    query = args.query
    top_k = args.top_k
    threshold = args.threshold

    existing = [c.name for c in client.get_collections().collections]
    if collection not in existing:
        print(json.dumps({"results": [], "note": f"collection '{collection}' not found"}))
        return

    translate = getattr(args, 'translate', False)
    vector = embed(query, translate=translate)
    results = client.query_points(
        collection_name=collection,
        query=vector,
        limit=top_k,
        score_threshold=threshold,
        with_payload=True
    ).points

    output = []
    for r in results:
        output.append({
            "score": round(r.score, 4),
            "id": r.id,
            "payload": r.payload
        })
    print(json.dumps({"results": output, "collection": collection, "query": query}))


def cmd_index_dir(args):
    directory = Path(args.directory).expanduser()
    collection = args.collection
    pattern = args.pattern or "*.md"
    files = list(directory.glob(pattern))

    ensure_collection(collection)
    indexed = 0
    errors = 0

    for fpath in files:
        try:
            text = fpath.read_text(encoding="utf-8").strip()
            if not text:
                continue
            point_id = text_to_id(str(fpath))
            vector = embed(text)
            client.upsert(
                collection_name=collection,
                points=[PointStruct(
                    id=point_id,
                    vector=vector,
                    payload={
                        "text": text[:2000],  # store first 2000 chars
                        "file": str(fpath),
                        "name": fpath.stem,
                        "indexed_at": datetime.utcnow().isoformat()
                    }
                )]
            )
            indexed += 1
            print(f"  ✓ {fpath.name}", file=sys.stderr)
        except Exception as e:
            print(f"  ✗ {fpath.name}: {e}", file=sys.stderr)
            errors += 1

    print(json.dumps({"indexed": indexed, "errors": errors, "collection": collection}))


def cmd_index_memories(args):
    memory_dir = Path("~/.claude/memory").expanduser()
    print(f"Indexing memories from {memory_dir}...", file=sys.stderr)

    # Index all .md files recursively
    ensure_collection("helix_memory")
    indexed = 0

    for fpath in memory_dir.rglob("*.md"):
        try:
            text = fpath.read_text(encoding="utf-8").strip()
            if not text:
                continue
            # Use relative path as stable ID base
            rel = str(fpath.relative_to(memory_dir))
            point_id = text_to_id(rel)
            vector = embed(text)
            client.upsert(
                collection_name="helix_memory",
                points=[PointStruct(
                    id=point_id,
                    vector=vector,
                    payload={
                        "text": text[:3000],
                        "file": str(fpath),
                        "relative_path": rel,
                        "name": fpath.stem,
                        "indexed_at": datetime.utcnow().isoformat()
                    }
                )]
            )
            indexed += 1
            print(f"  ✓ {rel}", file=sys.stderr)
        except Exception as e:
            print(f"  ✗ {fpath}: {e}", file=sys.stderr)

    print(json.dumps({"indexed": indexed, "collection": "helix_memory"}))


def _extract_agent_index_text(content: str, max_chars: int = 4000) -> str:
    """Extrae las partes más semánticamente ricas de un agente para indexar."""
    import re
    parts = []

    # 1. Frontmatter completo (description + name + tools)
    if content.startswith("---"):
        end = content.find("---", 3)
        if end > 0:
            parts.append(content[:end+3])

    body = content[content.find("---", 3)+3:].strip() if content.startswith("---") else content

    # 2. Ejemplos (lo más semánticamente rico para routing)
    examples = re.findall(r'<example>.*?</example>', body, re.DOTALL)
    for ex in examples[:3]:  # máx 3 ejemplos
        parts.append(ex)

    # 3. Sección "Cuándo invocar" / triggers
    trigger_m = re.search(r'(## (?:Cuándo invocar|When to use|Use when).*?)(?=\n##|\Z)', body, re.DOTALL|re.IGNORECASE)
    if trigger_m:
        parts.append(trigger_m.group(1)[:500])

    # 4. Vocabulario de usuario
    vocab_m = re.search(r'(## (?:Vocabulario|Vocabulary|Extended vocabulary).*?)(?=\n##|\Z)', body, re.DOTALL|re.IGNORECASE)
    if vocab_m:
        parts.append(vocab_m.group(1)[:400])

    # Combinar y truncar
    combined = "\n\n".join(parts)
    if not combined.strip():
        combined = content  # fallback al contenido completo

    return combined[:max_chars]


def cmd_index_agents(args):
    agents_dir = Path("~/.claude/memory/agents").expanduser()
    agents_index = Path("~/.claude/memory/agents-index.md").expanduser()

    ensure_collection("helix_agents")
    indexed = 0

    # Index individual agent files
    if agents_dir.exists():
        for fpath in agents_dir.glob("*.md"):
            try:
                text = fpath.read_text(encoding="utf-8").strip()
                if not text:
                    continue
                # Extract semantically rich parts: frontmatter + first body section
                # nomic-embed-text has ~8k token limit; 4000 chars is safe
                index_text = _extract_agent_index_text(text)
                point_id = text_to_id(f"agent:{fpath.stem}")
                vector = embed(index_text)
                client.upsert(
                    collection_name="helix_agents",
                    points=[PointStruct(
                        id=point_id,
                        vector=vector,
                        payload={
                            "text": text[:3000],
                            "agent": fpath.stem,
                            "file": str(fpath),
                            "indexed_at": datetime.utcnow().isoformat()
                        }
                    )]
                )
                indexed += 1
                print(f"  ✓ agent: {fpath.stem}", file=sys.stderr)
            except Exception as e:
                print(f"  ✗ {fpath.stem}: {e}", file=sys.stderr)

    print(json.dumps({"indexed": indexed, "collection": "helix_agents"}))


def cmd_list_collections(args):
    collections = client.get_collections().collections
    output = []
    for c in collections:
        info = client.get_collection(c.name)
        output.append({
            "name": c.name,
            "points_count": info.points_count or 0,
            "indexed_vectors_count": info.indexed_vectors_count or 0
        })
    print(json.dumps({"collections": output}))


def cmd_delete(args):
    existing = [c.name for c in client.get_collections().collections]
    if args.collection not in existing:
        print(json.dumps({"status": "not_found"}))
        return
    client.delete(collection_name=args.collection, points_selector=[args.id])
    print(json.dumps({"status": "deleted", "id": args.id}))


def main():
    parser = argparse.ArgumentParser(description="Helix Vector Memory Engine")
    sub = parser.add_subparsers(dest="command")

    # store
    p_store = sub.add_parser("store")
    p_store.add_argument("collection")
    p_store.add_argument("text")
    p_store.add_argument("--id")
    p_store.add_argument("--meta", nargs="*")

    # search
    p_search = sub.add_parser("search")
    p_search.add_argument("collection")
    p_search.add_argument("query")
    p_search.add_argument("--top-k", type=int, default=5)
    p_search.add_argument("--threshold", type=float, default=0.45)
    p_search.add_argument("--translate", action="store_true", help="Translate query to English before embedding")

    # index-dir
    p_dir = sub.add_parser("index-dir")
    p_dir.add_argument("directory")
    p_dir.add_argument("collection")
    p_dir.add_argument("--pattern", default="*.md")

    # index-memories
    sub.add_parser("index-memories")

    # index-agents
    sub.add_parser("index-agents")

    # list-collections
    sub.add_parser("list-collections")

    # delete
    p_del = sub.add_parser("delete")
    p_del.add_argument("collection")
    p_del.add_argument("id")

    args = parser.parse_args()

    commands = {
        "store": cmd_store,
        "search": cmd_search,
        "index-dir": cmd_index_dir,
        "index-memories": cmd_index_memories,
        "index-agents": cmd_index_agents,
        "list-collections": cmd_list_collections,
        "delete": cmd_delete,
    }

    if not args.command or args.command not in commands:
        parser.print_help()
        sys.exit(1)

    try:
        commands[args.command](args)
    except requests.exceptions.ConnectionError as e:
        print(json.dumps({"error": f"Connection failed: {e}"}), file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(json.dumps({"error": str(e)}), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
