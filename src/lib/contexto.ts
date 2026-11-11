import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { createClient } from "./supabase/server";

export const TENANT_COOKIE = "r360_tenant";
export type Papel = "owner" | "admin" | "tecnico" | "medico" | "leitor" | "cliente";

export const NOME_PAPEL: Record<Papel, string> = {
  owner: "Proprietário",
  admin: "Administrador",
  tecnico: "Técnico",
  medico: "Médico",
  leitor: "Leitura",
  cliente: "Cliente",
};

type Vinculo = { tenant_id: string; role: Papel; tenants: { name: string } | null };

/** Usuário logado + conta (tenant) atual. Redireciona se faltar algo. */
export async function getContexto() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const { data } = await supabase
    .from("tenant_users")
    .select("tenant_id, role, tenants(name)")
    .eq("user_id", user.id);
  const vinculos = (data ?? []) as unknown as Vinculo[];
  if (!vinculos.length) redirect("/onboarding");

  const escolhido = (await cookies()).get(TENANT_COOKIE)?.value;
  const atual = vinculos.find((v) => v.tenant_id === escolhido) ?? vinculos[0];

  return {
    supabase,
    user,
    tenantId: atual.tenant_id,
    tenantNome: atual.tenants?.name ?? "",
    papel: atual.role,
    vinculos,
  };
}
