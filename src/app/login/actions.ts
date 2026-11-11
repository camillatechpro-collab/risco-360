"use server";

import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export type Estado = { erro?: string; ok?: string } | undefined;

const MENSAGENS: Record<string, string> = {
  "Invalid login credentials": "E-mail ou senha incorretos.",
  "Email not confirmed": "Confirme seu e-mail pelo link que enviamos antes de entrar.",
  "User already registered": "Já existe uma conta com este e-mail.",
};
const traduzir = (m: string) => MENSAGENS[m] ?? m;

export async function entrar(_: Estado, fd: FormData): Promise<Estado> {
  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithPassword({
    email: String(fd.get("email") ?? "").trim(),
    password: String(fd.get("senha") ?? ""),
  });
  if (error) return { erro: traduzir(error.message) };
  redirect("/painel");
}

export async function cadastrar(_: Estado, fd: FormData): Promise<Estado> {
  const nome = String(fd.get("nome") ?? "").trim();
  const email = String(fd.get("email") ?? "").trim();
  const senha = String(fd.get("senha") ?? "");
  if (!nome) return { erro: "Informe seu nome." };
  if (senha.length < 8) return { erro: "A senha precisa ter pelo menos 8 caracteres." };

  const origin = (await headers()).get("origin") ?? "http://localhost:3000";
  const supabase = await createClient();
  const { data, error } = await supabase.auth.signUp({
    email,
    password: senha,
    options: { emailRedirectTo: `${origin}/auth/callback`, data: { nome } },
  });
  if (error) return { erro: traduzir(error.message) };
  if (!data.session) return { ok: "Conta criada. Enviamos um link de confirmação para o seu e-mail." };
  redirect("/onboarding");
}

export async function sair() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect("/login");
}
