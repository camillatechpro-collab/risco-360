# Risco360

SaaS de gestão de SST: cadastro de empresas, GHE e inventário de riscos, com geração de PGR, PCMSO e LTCAT a partir da mesma base.

## Estrutura

- `src/` — aplicação Next.js (App Router, TypeScript, Tailwind)
- `supabase/migrations/` — esquema do banco (PostgreSQL + RLS)
- `prototipo/index.html` — protótipo navegável (sem servidor), referência de telas e regras

## Rodar localmente

1. Copie `.env.example` para `.env.local` e preencha a chave pública do Supabase.
2. As migrações de `supabase/migrations/` são aplicadas automaticamente pela integração GitHub do Supabase a cada envio para o branch `main`. Nunca edite uma migração já aplicada: crie um arquivo novo.
3. `npm install` e `npm run dev`, depois abra http://localhost:3000

## Fases

| Fase | Entrega | Situação |
|---|---|---|
| 0 | Login e estrutura de contas | em andamento |
| 1 | Empresas, estrutura organizacional e GHE | — |
| 2 | Inventário de riscos | — |
| 3 | Plano de ação e PGR | — |
| 4 | PCMSO e gestão ocupacional | — |
| 5 | LTCAT | — |
| 6 | Gestão avançada | — |
| 7 | IA, integrações e comercialização | — |
