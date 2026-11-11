-- =====================================================================
-- Risco360 — Migração 0001: fundação do MVP (Fases 0 a 3)
-- Contas/tenants, estrutura organizacional, GHE, inventário de riscos,
-- matriz configurável, plano de ação, documentos versionados e auditoria.
--
-- Regras centrais:
--  * Toda tabela de negócio tem tenant_id.
--  * FKs compostas (tenant_id, id) impedem ligar registros de tenants diferentes.
--  * RLS em todas as tabelas; o front-end nunca enxerga outro tenant.
--  * Biblioteca de riscos e matriz são versionadas: avaliações antigas
--    apontam para a versão usada e não mudam silenciosamente.
--  * Versões aprovadas de documentos são imutáveis.
--  * Trabalhadores, exames e ASO (dados de saúde) ficam para a Fase 4,
--    em migração própria com controles de acesso específicos.
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- 1. Contas, usuários e papéis
-- ---------------------------------------------------------------------
create type tenant_role as enum ('owner','admin','tecnico','medico','leitor','cliente');

create table tenants (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  document    text,                                   -- CNPJ/CPF da consultoria
  kind        text not null default 'consultoria' check (kind in ('consultoria','empresa')),
  plan        text not null default 'trial',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table tenant_users (
  tenant_id   uuid not null references tenants on delete cascade,
  user_id     uuid not null references auth.users on delete cascade,
  role        tenant_role not null default 'tecnico',
  professional_title    text,                         -- ex.: Técnico em Segurança do Trabalho
  professional_registry text,                         -- ex.: MTE 12345 / CREA / CRM
  created_at  timestamptz not null default now(),
  primary key (tenant_id, user_id)
);
create index on tenant_users (user_id);

create or replace function is_member(t uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from tenant_users where tenant_id = t and user_id = auth.uid())
$$;

create or replace function has_role(t uuid, roles tenant_role[]) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from tenant_users
                 where tenant_id = t and user_id = auth.uid() and role = any (roles))
$$;

-- Cria a conta e já vincula o usuário logado como owner
create or replace function create_tenant(p_name text, p_document text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare t uuid;
begin
  if auth.uid() is null then raise exception 'Usuário não autenticado'; end if;
  insert into tenants (name, document) values (p_name, p_document) returning id into t;
  insert into tenant_users (tenant_id, user_id, role) values (t, auth.uid(), 'owner');
  return t;
end $$;

-- ---------------------------------------------------------------------
-- 2. Utilitários: updated_at e auditoria
-- ---------------------------------------------------------------------
create or replace function set_updated_at() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

create table audit_logs (
  id          bigint generated always as identity primary key,
  tenant_id   uuid references tenants on delete cascade,
  table_name  text not null,
  record_id   uuid,
  action      text not null,                          -- INSERT / UPDATE / DELETE
  old_data    jsonb,
  new_data    jsonb,
  user_id     uuid,
  created_at  timestamptz not null default now()
);
create index on audit_logs (tenant_id, table_name, record_id);

create or replace function audit_trigger() returns trigger
language plpgsql security definer set search_path = public as $$
declare r jsonb;
begin
  r := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
  insert into audit_logs (tenant_id, table_name, record_id, action, old_data, new_data, user_id)
  values ((r->>'tenant_id')::uuid, tg_table_name, (r->>'id')::uuid, tg_op,
          case when tg_op <> 'INSERT' then to_jsonb(old) end,
          case when tg_op <> 'DELETE' then to_jsonb(new) end,
          auth.uid());
  return coalesce(new, old);
end $$;

-- ---------------------------------------------------------------------
-- 3. Empresas e estrutura organizacional
--    Empresa → Unidade → Setor → Ambiente / Cargo
-- ---------------------------------------------------------------------
create table companies (
  id                 uuid primary key default gen_random_uuid(),
  tenant_id          uuid not null references tenants on delete cascade,
  cnpj               text,
  legal_name         text not null,
  trade_name         text,
  cnae_main          text,
  cnae_main_desc     text,
  cnaes_secondary    jsonb not null default '[]',
  risk_grade         smallint check (risk_grade between 1 and 4),
  risk_grade_validated_by uuid references auth.users,  -- validação manual com o Anexo I da NR-4
  registration_status text,
  street text, number text, complement text, district text, city text, state char(2), zip text,
  activity_description text,
  work_schedule      text,
  contact_name text, contact_email text, contact_phone text,
  cnpj_source        text,                            -- ex.: 'brasilapi'
  cnpj_consulted_at  timestamptz,
  active             boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, id)
);
create unique index companies_tenant_cnpj on companies (tenant_id, cnpj) where cnpj is not null;

create table company_units (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null references tenants on delete cascade,
  company_id  uuid not null,
  name        text not null,
  cnpj        text,
  address     text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, id),
  foreign key (tenant_id, company_id) references companies (tenant_id, id) on delete cascade
);

create table sectors (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null references tenants on delete cascade,
  unit_id     uuid not null,
  name        text not null,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, id),
  foreign key (tenant_id, unit_id) references company_units (tenant_id, id) on delete cascade
);

create table work_environments (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null references tenants on delete cascade,
  sector_id   uuid not null,
  name        text not null,
  description text,
  area_m2     numeric,
  floor_type text, roof_type text, lighting text, ventilation text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, id),
  foreign key (tenant_id, sector_id) references sectors (tenant_id, id) on delete cascade
);

create table cbo_catalog (                            -- global, carregado da tabela oficial
  code  text primary key,                             -- formato 0000-00
  title text not null
);

create table positions (                              -- cargos / funções
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null references tenants on delete cascade,
  company_id  uuid not null,
  sector_id   uuid,
  name        text not null,
  cbo_code    text,
  activities  text,                                   -- descrição das atividades
  headcount   integer not null default 0 check (headcount >= 0),
  shift       text,
  work_schedule text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, id),
  foreign key (tenant_id, company_id) references companies (tenant_id, id) on delete cascade,
  foreign key (tenant_id, sector_id)  references sectors   (tenant_id, id) on delete set null (sector_id)
);

-- ---------------------------------------------------------------------
-- 4. GHE
-- ---------------------------------------------------------------------
create table ghes (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null references tenants on delete cascade,
  company_id  uuid not null,
  unit_id     uuid,
  code        text,                                   -- ex.: GHE 01
  name        text not null,
  description text,
  cloned_from uuid,                                   -- rastreia clonagem (valores técnicos não são copiados)
  active      boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, id),
  foreign key (tenant_id, company_id) references companies     (tenant_id, id) on delete cascade,
  foreign key (tenant_id, unit_id)    references company_units (tenant_id, id) on delete set null (unit_id)
);

create table ghe_positions (
  tenant_id   uuid not null references tenants on delete cascade,
  ghe_id      uuid not null,
  position_id uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (ghe_id, position_id),
  foreign key (tenant_id, ghe_id)      references ghes      (tenant_id, id) on delete cascade,
  foreign key (tenant_id, position_id) references positions (tenant_id, id) on delete cascade
);

create table ghe_environments (
  tenant_id      uuid not null references tenants on delete cascade,
  ghe_id         uuid not null,
  environment_id uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (ghe_id, environment_id),
  foreign key (tenant_id, ghe_id)         references ghes              (tenant_id, id) on delete cascade,
  foreign key (tenant_id, environment_id) references work_environments (tenant_id, id) on delete cascade
);

-- ---------------------------------------------------------------------
-- 5. Biblioteca de riscos (versionada) e matriz configurável
--    tenant_id NULL = biblioteca padrão Risco360 (somente leitura p/ clientes)
-- ---------------------------------------------------------------------
create table risk_categories (
  code  text primary key,
  name  text not null,
  color text not null
);

create table risk_agents (
  id              uuid primary key default gen_random_uuid(),
  tenant_id       uuid references tenants on delete cascade,
  category        text not null references risk_categories,
  name            text not null,
  current_version integer not null default 1,
  active          boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table risk_agent_versions (                    -- imutável: nova referência = nova versão
  id                 uuid primary key default gen_random_uuid(),
  tenant_id          uuid references tenants on delete cascade,
  agent_id           uuid not null references risk_agents on delete cascade,
  version            integer not null,
  description        text,
  typical_sources    text,
  health_effects     text,
  exposure_routes    text,
  assessment_method  text,                            -- ex.: NHO-01
  unit               text,
  exposure_limit     numeric,
  limit_reference    text,                            -- ex.: NR-15 Anexo 1
  legal_basis        text,
  esocial_code       text,                            -- Tabela 24
  anexo_iv_code      text,                            -- Decreto 3.048/99
  qualitative_only   boolean not null default false,  -- ex.: cancerígenos LINACH grupo 1
  suggested_controls text,
  suggested_exams    jsonb not null default '[]',     -- [{exame, periodicidade}] — apenas sugestão
  valid_from         date not null default current_date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (agent_id, version)
);

create table risk_matrix_configs (                    -- não editar após uso: criar nova versão
  id                 uuid primary key default gen_random_uuid(),
  tenant_id          uuid references tenants on delete cascade,
  name               text not null,
  version            integer not null default 1,
  method_description text not null,
  probability_scale  jsonb not null,                  -- [{valor, rotulo, descricao}]
  severity_scale     jsonb not null,
  levels             jsonb not null,                  -- [{label, min, max, cor, acao}]
  active             boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 6. Inventário de riscos
-- ---------------------------------------------------------------------
create table ghe_risks (
  id               uuid primary key default gen_random_uuid(),
  tenant_id        uuid not null references tenants on delete cascade,
  ghe_id           uuid not null,
  agent_id         uuid references risk_agents,
  agent_version_id uuid references risk_agent_versions,  -- versão da biblioteca usada
  category         text not null references risk_categories,
  hazard_name      text not null,                       -- cópia do nome no momento do lançamento
  source           text,                                -- fonte geradora
  circumstance     text,
  activity         text,
  exposure_type    text check (exposure_type in ('habitual_permanente','habitual_intermitente','eventual')),
  frequency        text,
  duration         text,
  exposed_count    integer,
  health_effects   text,
  status           text not null default 'ativo' check (status in ('ativo','eliminado')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, id),
  foreign key (tenant_id, ghe_id) references ghes (tenant_id, id) on delete cascade
);

create table risk_assessments (
  id               uuid primary key default gen_random_uuid(),
  tenant_id        uuid not null references tenants on delete cascade,
  ghe_risk_id      uuid not null,
  assessment_type  text not null check (assessment_type in ('qualitativa','quantitativa')),
  matrix_config_id uuid not null references risk_matrix_configs,
  probability      smallint not null check (probability between 1 and 10),
  severity         smallint not null check (severity between 1 and 10),
  score            integer,                             -- calculado por trigger
  level_label      text,                                -- calculado por trigger
  assessed_by      uuid references auth.users default auth.uid(),
  assessed_at      timestamptz not null default now(),
  is_current       boolean not null default true,
  notes            text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, id),
  foreign key (tenant_id, ghe_risk_id) references ghe_risks (tenant_id, id) on delete cascade
);
create index on risk_assessments (ghe_risk_id) where is_current;

create or replace function risk_assessment_calc() returns trigger language plpgsql as $$
declare lvl jsonb;
begin
  new.score := new.probability * new.severity;
  select l into lvl
    from risk_matrix_configs c, jsonb_array_elements(c.levels) l
   where c.id = new.matrix_config_id
     and new.score between (l->>'min')::int and (l->>'max')::int
   limit 1;
  if lvl is null then raise exception 'Pontuação % fora das faixas da matriz %', new.score, new.matrix_config_id; end if;
  new.level_label := lvl->>'label';
  if tg_op = 'INSERT' and new.is_current then
    update risk_assessments set is_current = false
     where ghe_risk_id = new.ghe_risk_id and is_current;
  end if;
  return new;
end $$;
create trigger risk_assessments_calc before insert or update of probability, severity, matrix_config_id
  on risk_assessments for each row execute function risk_assessment_calc();

create table quantitative_measurements (
  id                 uuid primary key default gen_random_uuid(),
  tenant_id          uuid not null references tenants on delete cascade,
  assessment_id      uuid not null,
  method             text,                            -- ex.: NHO-01 dosimetria
  instrument         text,
  instrument_serial  text,
  calibration_date   date,
  measured_at        date,
  sample_duration    text,
  result             numeric not null,
  unit               text not null,
  exposure_limit     numeric,
  limit_reference    text,
  notes              text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, id),
  foreign key (tenant_id, assessment_id) references risk_assessments (tenant_id, id) on delete cascade
);

create table risk_controls (
  id           uuid primary key default gen_random_uuid(),
  tenant_id    uuid not null references tenants on delete cascade,
  ghe_risk_id  uuid not null,
  control_type text not null check (control_type in ('eliminacao','substituicao','epc','administrativa','epi')),
  situation    text not null default 'existente' check (situation in ('existente','recomendada')),
  description  text not null,
  ca_number    text,                                  -- EPI
  effective    boolean,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, id),
  foreign key (tenant_id, ghe_risk_id) references ghe_risks (tenant_id, id) on delete cascade
);

create table evidences (                              -- fotos, laudos, certificados (Supabase Storage)
  id           uuid primary key default gen_random_uuid(),
  tenant_id    uuid not null references tenants on delete cascade,
  entity_type  text not null,                         -- ex.: 'ghe_risk', 'measurement', 'action_item'
  entity_id    uuid not null,
  storage_path text not null,                         -- bucket privado: {tenant_id}/...
  file_name    text not null,
  mime_type    text,
  uploaded_by  uuid references auth.users default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on evidences (tenant_id, entity_type, entity_id);

-- ---------------------------------------------------------------------
-- 7. Plano de ação (histórico via audit_logs)
-- ---------------------------------------------------------------------
create table action_items (
  id               uuid primary key default gen_random_uuid(),
  tenant_id        uuid not null references tenants on delete cascade,
  company_id       uuid not null,
  ghe_risk_id      uuid,
  description      text not null,
  priority         text not null default 'media' check (priority in ('baixa','media','alta','critica')),
  responsible_name text,
  responsible_user uuid references auth.users,
  due_date         date,
  status           text not null default 'nao_iniciada'
                   check (status in ('nao_iniciada','em_andamento','concluida','cancelada')),
  completed_at     date,
  notes            text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, id),
  foreign key (tenant_id, company_id)  references companies (tenant_id, id) on delete cascade,
  foreign key (tenant_id, ghe_risk_id) references ghe_risks (tenant_id, id) on delete set null (ghe_risk_id)
);

-- "Atrasada" é derivado da data, não gravado
create view action_items_status with (security_invoker = true) as
select a.*,
       case when a.status in ('nao_iniciada','em_andamento') and a.due_date < current_date
            then 'atrasada' else a.status end as effective_status
  from action_items a;

-- ---------------------------------------------------------------------
-- 8. Documentos versionados (PGR, PCMSO, LTCAT)
-- ---------------------------------------------------------------------
create table document_templates (
  id           uuid primary key default gen_random_uuid(),
  tenant_id    uuid references tenants on delete cascade,  -- NULL = modelo padrão
  doc_type     text not null check (doc_type in ('PGR','PCMSO','LTCAT')),
  name         text not null,
  version      integer not null default 1,
  storage_path text,                                  -- .docx com marcadores
  active       boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table documents (
  id              uuid primary key default gen_random_uuid(),
  tenant_id       uuid not null references tenants on delete cascade,
  company_id      uuid not null,
  doc_type        text not null check (doc_type in ('PGR','PCMSO','LTCAT')),
  title           text not null,
  current_version integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, id),
  foreign key (tenant_id, company_id) references companies (tenant_id, id) on delete cascade
);

create table document_versions (
  id            uuid primary key default gen_random_uuid(),
  tenant_id     uuid not null references tenants on delete cascade,
  document_id   uuid not null,
  version       integer not null,
  status        text not null default 'rascunho'
                check (status in ('rascunho','em_revisao','aprovado','substituido')),
  data_snapshot jsonb not null,                       -- todos os dados usados na geração
  template_id   uuid references document_templates,
  pdf_path      text,
  docx_path     text,
  valid_from    date,
  review_due    date,                                 -- ex.: PGR = +2 anos
  change_summary text,
  created_by    uuid references auth.users default auth.uid(),
  approved_by   uuid references auth.users,
  approved_at   timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, id),
  unique (document_id, version),
  foreign key (tenant_id, document_id) references documents (tenant_id, id) on delete cascade
);

create or replace function document_versions_lock() returns trigger language plpgsql as $$
begin
  if old.status = 'aprovado' then
    if new.status not in ('aprovado','substituido')
       or new.data_snapshot is distinct from old.data_snapshot
       or new.pdf_path      is distinct from old.pdf_path
       or new.docx_path     is distinct from old.docx_path
       or new.approved_by   is distinct from old.approved_by then
      raise exception 'Versão aprovada não pode ser alterada. Crie uma nova versão.';
    end if;
  end if;
  return new;
end $$;
create trigger document_versions_lock before update on document_versions
  for each row execute function document_versions_lock();

create table document_approvals (                     -- aprovação / assinatura por responsável
  id                    uuid primary key default gen_random_uuid(),
  tenant_id             uuid not null references tenants on delete cascade,
  version_id            uuid not null,
  user_id               uuid not null references auth.users default auth.uid(),
  role_title            text not null,               -- ex.: Médico responsável pelo PCMSO
  professional_registry text,
  decision              text not null check (decision in ('aprovado','reprovado')),
  comment               text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (tenant_id, version_id) references document_versions (tenant_id, id) on delete cascade
);

-- ---------------------------------------------------------------------
-- 9. RLS, auditoria e updated_at em todas as tabelas de negócio
-- ---------------------------------------------------------------------
alter table tenants      enable row level security;
alter table tenant_users enable row level security;
alter table audit_logs   enable row level security;
alter table cbo_catalog  enable row level security;
alter table risk_categories enable row level security;

create policy tenants_select on tenants for select using (is_member(id));
create policy tenants_update on tenants for update using (has_role(id, array['owner','admin']::tenant_role[]));
create policy tenant_users_select on tenant_users for select using (is_member(tenant_id));
create policy tenant_users_write  on tenant_users for all
  using (has_role(tenant_id, array['owner','admin']::tenant_role[]))
  with check (has_role(tenant_id, array['owner','admin']::tenant_role[]));
create policy audit_select on audit_logs for select using (has_role(tenant_id, array['owner','admin']::tenant_role[]));
create policy cbo_select on cbo_catalog for select to authenticated using (true);
create policy categories_select on risk_categories for select to authenticated using (true);

create trigger tenants_updated before update on tenants for each row execute function set_updated_at();

-- Tabelas do tenant: leitura para membros (exceto 'cliente', que terá o portal),
-- escrita para owner/admin/tecnico/medico.
do $$
declare t text;
begin
  foreach t in array array[
    'companies','company_units','sectors','work_environments','positions',
    'ghes','ghe_positions','ghe_environments',
    'ghe_risks','risk_assessments','quantitative_measurements','risk_controls','evidences',
    'action_items','documents','document_versions','document_approvals'
  ] loop
    execute format('alter table %I enable row level security', t);
    execute format($p$create policy %1$s_select on %1$I for select
      using (has_role(tenant_id, array['owner','admin','tecnico','medico','leitor']::tenant_role[]))$p$, t);
    execute format($p$create policy %1$s_write on %1$I for all
      using (has_role(tenant_id, array['owner','admin','tecnico','medico']::tenant_role[]))
      with check (has_role(tenant_id, array['owner','admin','tecnico','medico']::tenant_role[]))$p$, t);
    execute format('create trigger %1$s_audit after insert or update or delete on %1$I
      for each row execute function audit_trigger()', t);
    execute format('create trigger %1$s_updated before update on %1$I
      for each row execute function set_updated_at()', t);
  end loop;
end $$;

-- Tabelas com conteúdo padrão (tenant_id NULL): todos leem o padrão,
-- cada tenant escreve só o próprio conteúdo.
do $$
declare t text;
begin
  foreach t in array array['risk_agents','risk_agent_versions','risk_matrix_configs','document_templates'] loop
    execute format('alter table %I enable row level security', t);
    execute format($p$create policy %1$s_select on %1$I for select to authenticated
      using (tenant_id is null or is_member(tenant_id))$p$, t);
    execute format($p$create policy %1$s_insert on %1$I for insert
      with check (tenant_id is not null and has_role(tenant_id, array['owner','admin','tecnico']::tenant_role[]))$p$, t);
    execute format('create trigger %1$s_audit after insert or update or delete on %1$I
      for each row execute function audit_trigger()', t);
    execute format('create trigger %1$s_updated before update on %1$I
      for each row execute function set_updated_at()', t);
  end loop;
end $$;

-- Agentes e modelos próprios podem ser editados (ex.: desativar); versões e matrizes não.
create policy risk_agents_update on risk_agents for update
  using (tenant_id is not null and has_role(tenant_id, array['owner','admin','tecnico']::tenant_role[]));
create policy document_templates_update on document_templates for update
  using (tenant_id is not null and has_role(tenant_id, array['owner','admin']::tenant_role[]));

-- ---------------------------------------------------------------------
-- 10. Dados iniciais
-- ---------------------------------------------------------------------
insert into risk_categories (code, name, color) values
  ('fisico','Físico','#2e9d4f'),
  ('quimico','Químico','#d63b3b'),
  ('biologico','Biológico','#8a5a2b'),
  ('ergonomico','Ergonômico','#d39e00'),
  ('acidente','Acidente / Mecânico','#2f6fd6'),
  ('psicossocial','Fatores psicossociais','#8a4fd6');

insert into risk_matrix_configs (tenant_id, name, version, method_description, probability_scale, severity_scale, levels) values
(null, 'Matriz 5×5 Risco360', 1,
 'Nível de risco = Probabilidade × Severidade, considerando as medidas de prevenção existentes.',
 '[{"valor":1,"rotulo":"Rara"},{"valor":2,"rotulo":"Improvável"},{"valor":3,"rotulo":"Possível"},{"valor":4,"rotulo":"Provável"},{"valor":5,"rotulo":"Quase certa"}]',
 '[{"valor":1,"rotulo":"Insignificante"},{"valor":2,"rotulo":"Leve"},{"valor":3,"rotulo":"Moderada"},{"valor":4,"rotulo":"Grave"},{"valor":5,"rotulo":"Catastrófica"}]',
 '[{"label":"Baixo","min":1,"max":4,"cor":"#43a047","acao":"Manter controles e monitorar"},
   {"label":"Moderado","min":5,"max":9,"cor":"#f9a825","acao":"Melhorias planejadas"},
   {"label":"Alto","min":10,"max":14,"cor":"#ef6c00","acao":"Ação prioritária em curto prazo"},
   {"label":"Crítico","min":15,"max":25,"cor":"#c62828","acao":"Ação imediata; avaliar interrupção"}]');

-- A biblioteca de agentes do protótipo (index.html) será importada por script de seed
-- na Fase 2, com revisão técnica de limites, códigos e referências antes da carga.
