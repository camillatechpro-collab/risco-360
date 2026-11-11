"use client";

import { useActionState, useState } from "react";
import { cadastrar, entrar, type Estado } from "./actions";

const campo =
  "mt-1 w-full rounded-md border border-slate-300 px-3 py-2 outline-none focus:border-destaque focus:ring-2 focus:ring-destaque/40";

export function LoginForm() {
  const [modo, setModo] = useState<"entrar" | "cadastrar">("entrar");
  return (
    <div className="rounded-xl bg-white p-6 shadow-xl">
      <div className="mb-5 grid grid-cols-2 rounded-lg bg-slate-100 p-1 text-sm font-semibold">
        {(["entrar", "cadastrar"] as const).map((m) => (
          <button
            key={m}
            type="button"
            onClick={() => setModo(m)}
            className={`rounded-md py-2 ${modo === m ? "bg-white text-marca-600 shadow" : "text-slate-500"}`}
          >
            {m === "entrar" ? "Entrar" : "Criar conta"}
          </button>
        ))}
      </div>
      {/* key força um formulário novo (e estado limpo) ao trocar de aba */}
      <Formulario key={modo} modo={modo} />
    </div>
  );
}

function Formulario({ modo }: { modo: "entrar" | "cadastrar" }) {
  const [estado, acao, pendente] = useActionState<Estado, FormData>(
    modo === "entrar" ? entrar : cadastrar,
    undefined,
  );
  return (
    <form action={acao} className="space-y-4">
      {modo === "cadastrar" && (
        <label className="block text-sm font-medium text-slate-600">
          Seu nome
          <input name="nome" required className={campo} autoComplete="name" />
        </label>
      )}
      <label className="block text-sm font-medium text-slate-600">
        E-mail
        <input name="email" type="email" required className={campo} autoComplete="email" />
      </label>
      <label className="block text-sm font-medium text-slate-600">
        Senha
        <input
          name="senha"
          type="password"
          required
          minLength={modo === "cadastrar" ? 8 : undefined}
          className={campo}
          autoComplete={modo === "entrar" ? "current-password" : "new-password"}
        />
      </label>

      {estado?.erro && <p className="rounded-md bg-red-50 p-3 text-sm text-red-700">{estado.erro}</p>}
      {estado?.ok && <p className="rounded-md bg-marca-50 p-3 text-sm text-marca-700">{estado.ok}</p>}

      <button
        disabled={pendente}
        className="w-full rounded-md bg-marca-600 py-2.5 font-semibold text-white hover:bg-marca-700 disabled:opacity-60"
      >
        {pendente ? "Aguarde..." : modo === "entrar" ? "Entrar" : "Criar conta"}
      </button>
    </form>
  );
}
