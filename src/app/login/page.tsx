import { supabaseConfigurado } from "@/lib/supabase/env";
import { LoginForm } from "./login-form";

export default function LoginPage() {
  return (
    <main className="flex min-h-screen items-center justify-center bg-marca-900 p-4">
      <div className="w-full max-w-md">
        <div className="mb-6 text-center text-white">
          <h1 className="text-4xl font-light">
            Risco<b className="font-bold text-destaque">360</b>
          </h1>
          <p className="mt-1 text-sm text-white/70">
            Cadastrar uma vez. Gerar PGR, PCMSO e LTCAT com rastreabilidade.
          </p>
        </div>
        {supabaseConfigurado ? (
          <LoginForm />
        ) : (
          <div className="rounded-xl bg-white p-6 text-sm shadow-xl">
            <b>Configuração pendente.</b> Preencha <code>NEXT_PUBLIC_SUPABASE_ANON_KEY</code> no arquivo{" "}
            <code>.env.local</code> e reinicie o servidor.
          </div>
        )}
      </div>
    </main>
  );
}
