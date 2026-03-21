-- Activation de l'extension pgvector
-- Exécuté automatiquement au premier démarrage du container postgres

CREATE EXTENSION IF NOT EXISTS vector;

-- Schema dédié pour les données vectorielles du Chief of Staff
CREATE SCHEMA IF NOT EXISTS memory;

-- Table exemple pour les embeddings (mémoire long terme)
-- À utiliser avec le node Postgres de n8n
CREATE TABLE IF NOT EXISTS memory.documents (
    id          BIGSERIAL PRIMARY KEY,
    content     TEXT NOT NULL,
    metadata    JSONB DEFAULT '{}',
    embedding   VECTOR(1536),         -- OpenAI text-embedding-ada-002 / compatible embeddings
                                      -- NOTE: DeepSeek embedding models may use different dims
                                      -- (e.g. 4096). Recreate table if switching embedding models.
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Index HNSW pour la recherche vectorielle rapide
CREATE INDEX IF NOT EXISTS documents_embedding_idx
    ON memory.documents
    USING hnsw (embedding vector_cosine_ops);