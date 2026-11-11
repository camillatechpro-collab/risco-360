import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { OnboardingForm } from "./onboarding-form";

// Depende da sessão do usuário: renderiza sob demanda (sem prerender).
export const instant = false;

export default async function OnboardingPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const { count } = await supabase
    .from("tenant_users")
    .select("tenant_id", { count: "exact", head: true })
    .eq("user_id", user.id);
  if (count) redirect("/painel");

  const nome = (user.user_metadata?.nome as string | undefined)?.split(" ")[0];

  return (
    <main className="flex min-h-screen items-center justify-center bg-marca-900 p-4">
      <div className="w-full max-w-md rounded-xl bg-white p-6 shadow-xl">
        <h1 className="text-xl font-bold">Bem-vindo(a){nome ? `, ${nome}` : ""}!</h1>
        <p className="mt-1 mb-5 text-sm text-slate-500">
          Vamos criar a conta da sua consultoria. As empresas que você atende ficarão dentro dela.
        </p>
        <OnboardingForm />
      </div>
    </main>
  );
}
