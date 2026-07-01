from typing import Dict, List, Any
import numpy as np

class AblationRetriever:
    def __init__(self, store: Any):
        self.store = store

    def rrf(self, rank_lists: List[List[str]], k: int = 60) -> List[tuple]:
        """ Computes Reciprocal Rank Fusion scores for unified document ranking. """
        rrf_scores = {}
        for rank_list in rank_lists:
            for rank, doc_id in enumerate(rank_list):
                if doc_id not in rrf_scores:
                    rrf_scores[doc_id] = 0.0
                rrf_scores[doc_id] += 1.0 / (k + (rank + 1))
        return sorted(rrf_scores.items(), key=lambda x: x[1], reverse=True)

    def retrieve(self, query_text: str, strategy: str = "hybrid", top_n: int = 2) -> Dict[str, List[Dict]]:
        results = {"logic_guides": [], "script_guides": [], "templates": [], "kt_docs": []}
        
        for section in results.keys():
            # Retrieval now runs over the chunked corpus (not whole files) so that
            # bm25_indices / dense_embeddings array positions line up correctly,
            # and so top_n returns relevant passages rather than entire documents.
            docs = self.store.chunks.get(section) if hasattr(self.store, "chunks") else None
            if not docs:
                docs = self.store.raw_documents.get(section, [])
            if not docs:
                continue
                
            doc_contents = [d["content"] for d in docs]
            
            # --- STRATEGY 1: SPARSE (BM25) ---
            sparse_ranked = []
            if strategy in ["sparse", "hybrid"] and section in self.store.bm25_indices:
                tokenized_query = query_text.lower().split(" ")
                scores = self.store.bm25_indices[section].get_scores(tokenized_query)
                top_indices = np.argsort(scores)[::-1]
                sparse_ranked = [docs[idx]["content"] for idx in top_indices if scores[idx] > 0]

            # --- STRATEGY 2: DENSE (Semantic vectors) ---
            dense_ranked = []
            if strategy in ["dense", "hybrid", "raptor"] and section in self.store.dense_embeddings:
                query_vector = self.store.encoder.encode([query_text], convert_to_numpy=True)
                matrix = self.store.dense_embeddings[section]
                # Cosine Similarity via Dot Product of normalized vectors
                norm_matrix = matrix / np.linalg.norm(matrix, axis=1, keepdims=True)
                norm_query = query_vector / np.linalg.norm(query_vector)
                similarities = np.dot(norm_matrix, norm_query.T).flatten()
                top_indices = np.argsort(similarities)[::-1]
                dense_ranked = [docs[idx]["content"] for idx in top_indices]

            # --- STRATEGY 3: RAPTOR (Tree-Aggregated Context) ---
            raptor_ranked = []
            if strategy == "raptor" and section == "kt_docs" and section in self.store.raptor_trees:
                raptor_nodes = self.store.raptor_trees[section]
                node_texts = [node["content"] for node in raptor_nodes]
                node_embeddings = self.store.encoder.encode(node_texts, convert_to_numpy=True)
                query_vector = self.store.encoder.encode([query_text], convert_to_numpy=True)
                sims = np.dot(node_embeddings, query_vector.T).flatten()
                raptor_ranked = [node_texts[idx] for idx in np.argsort(sims)[::-1]]

            # Combine selections based on execution scope
            if strategy == "sparse":
                selected_contents = sparse_ranked[:top_n]
            elif strategy == "dense":
                selected_contents = dense_ranked[:top_n]
            elif strategy == "raptor":
                # RAPTOR wraps dense layout with structured tree content
                selected_contents = (raptor_ranked[:1] + dense_ranked)[:top_n]
            elif strategy == "hybrid":
                merged = self.rrf([sparse_ranked, dense_ranked])
                selected_contents = [doc_id for doc_id, score in merged[:top_n]]
            else:
                selected_contents = doc_contents[:top_n]

            # Re-map contents back to payload object arrays
            results[section] = [{"content": c} for c in selected_contents]
            
        return results