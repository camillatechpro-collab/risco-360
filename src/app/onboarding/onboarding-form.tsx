"use client";

import { useActionState } from "react";
import { criarConta, type Estado } from "./actions";

const campo =
  "mt-1 w-full rounded-md border border-slate-300 px-3 py-2 outline-none focus:border-destaque focus:ring-2 focus:ring-destaque/40";

export function OnboardingForm() {
  const [estado, acao, pendente] = useActionState<Estado, FormData>(criarConta, undefined);
  return (
    <form action={acao} className="space-y-4">
      <label className="block text-sm font-medium text-slate-600">
        Nome da consultoria ou do profissional
        <input name="nome" required className={campo} placeholder="Ex.: Prevenir Consultoria em SST" />
      </label>
      <label className="block text-sm font-medium text-slate-600">
        CNPJ ou CPF (opcional)
        <input name="documento" className={campo} />
      </label>
      {estado?.erro && <p className="rounded-md bg-red-50 p-3 text-sm text-red-700">{estado.erro}</p>}
      <button
        disabled={pendente}
        className="w-full rounded-md bg-marca-600 py-2.5 font-semibold text-white hover:bg-marca-700 disabled:opacity-60"
      >
        {pendente ? "Criando..." : "Criar conta"}
      </button>
    </form>
  );
}
