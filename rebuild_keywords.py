#!/usr/bin/env python3
"""
Compatibility wrapper.

The previous TF-IDF fallback was replaced by the biomedical Transformer
pipeline in rebuild_transformer_embeddings.py. Keep this entry point only so
older instructions fail forward into the current method.
"""

from rebuild_transformer_embeddings import main


if __name__ == "__main__":
    print(
        "[DEPRECATED] rebuild_keywords.py now delegates to "
        "rebuild_transformer_embeddings.py."
    )
    main()
