"use server";

import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { TENANT_COOKIE } from "@/lib/contexto";
import { createClient } from "@/lib/supabase/server";

export type Estado = { erro?: string } | undefined;

export async function criarConta(_: Estado, fd: FormData): Promise<Estado> {
  const nome = String(fd.get("nome") ?? "").trim();
  const documento = String(fd.get("documento") ?? "").trim() || null;
  if (!nome) return { erro: "Informe o nome da consultoria." };

  const supabase = await createClient();
  const { data, error } = await supabase.rpc("create_tenant", { p_name: nome, p_document: documento });
  if (error) return { erro: "Não foi possível criar a conta: " + error.message };

  (await cookies()).set(TENANT_COOKIE, String(data), { path: "/", httpOnly: true, sameSite: "lax" });
  redirect("/painel");
}
