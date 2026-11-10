# MedLink DZ — AI agent configuration
## Provider adapters
All model calls run server-side in `src/lib/agent/provider-adapter.ts`. Supported adapters: `openai-compatible` (OpenAI Chat Completions JSON mode) and `google-gemini` (Gemini generateContent JSON mode).
Set server-only Vercel/local environment variables:
```env
MEDLINK_AI_PROVIDER=openai-compatible
MEDLINK_AI_BASE_URL=https://provider.example/v1
MEDLINK_AI_API_KEY=server-only-secret
MEDLINK_AI_MODEL=provider/model-id
```
Gemini: set `MEDLINK_AI_PROVIDER=google-gemini`, `MEDLINK_AI_API_KEY` and `MEDLINK_AI_MODEL`. Never prefix keys with `NEXT_PUBLIC_`. A configured provider and privacy/data-processing review are prerequisites for sending real patient information.
## Patient RAG boundary
The authenticated patient endpoint selects exactly one published plan using both plan ID and `patient_id=auth.uid()`. It retrieves only that plan's instructions and events. The model receives passages as untrusted data and returns passage indexes only. The application validates indexes and displays exact stored excerpts, never model-authored clinical prose. Deterministic safety rules run before retrieval. Unknown, urgent, clinical and detected prompt-injection requests are handed off.
This version uses plan-scoped chunk retrieval, not a vector/embedding database. It deliberately avoids cross-patient vector search. Any future vector index must enforce plan, patient, publication and doctor scope in database queries.
## Physician command structuring
`POST /api/agent/structure-follow-up` requires a verified physician, completed appointment, published consultation record and active Premium subscription. It creates a draft and draft events only. It never publishes. The physician reviews all generated dates and instructions and explicitly publishes.
## Safety
No diagnosis, prescription, symptom interpretation or treatment changes. The original patient message is stored only after handoff, on the escalation row visible to the patient and responsible physician under RLS. Structured outputs are validated. Provider failures fall back to deterministic responses. Tests do not constitute clinical validation or regulatory certification.
