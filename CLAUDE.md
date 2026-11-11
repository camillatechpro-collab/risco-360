# Risco360 — notas para o Claude

- Interface e textos em português do Brasil. Código e nomes de tabelas em inglês.
- Next.js 16: o antigo `middleware.ts` agora é `src/proxy.ts` (função `proxy`). Consulte `node_modules/next/dist/docs` antes de usar APIs que possam ter mudado.
- Supabase: clientes em `src/lib/supabase/` (`server.ts` para Server Components/Actions, `client.ts` para o navegador). Use `getContexto()` de `src/lib/contexto.ts` para obter usuário, tenant atual e papel.
- Toda tabela de negócio tem `tenant_id`, RLS e FKs compostas `(tenant_id, id)`. Mudanças no banco entram sempre como nova migração em `supabase/migrations/`, nunca editando uma já aplicada.
- Sugestões técnicas (exames do PCMSO, conclusão do LTCAT, IA) são sempre apresentadas como sugestão, com validação do profissional responsável.
- Nunca usar a chave `service_role` no front-end nem commitar `.env.local`.
