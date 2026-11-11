import Link from "next/link";
import { getContexto, NOME_PAPEL } from "@/lib/contexto";
import { sair } from "../login/actions";

// Área logada: depende da sessão do usuário, renderiza sob demanda (sem prerender).
export const instant = false;

const MENU: { href: string; label: string; fase?: string }[] = [
  { href: "/painel", label: "Painel" },
  { href: "/empresas", label: "Empresas", fase: "Fase 1" },
  { href: "/biblioteca", label: "Biblioteca de riscos", fase: "Fase 2" },
  { href: "/plano-de-acao", label: "Plano de ação", fase: "Fase 3" },
  { href: "/documentos", label: "Documentos", fase: "Fase 3" },
];

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const { user, tenantNome, papel } = await getContexto();

  return (
    <div className="flex min-h-screen">
      <aside className="sticky top-0 flex h-screen w-64 shrink-0 flex-col bg-marca-900 p-4 text-slate-100">
        <div className="px-2 pb-6 text-2xl font-light">
          Risco<b className="font-bold text-destaque">360</b>
          <small className="block text-[11px] tracking-wide text-white/60">Gestão de SST</small>
        </div>
        <nav className="space-y-1">
          {MENU.map((m) =>
            m.fase ? (
              <span key={m.href} className="flex items-center justify-between rounded-md px-3 py-2 text-white/40">
                {m.label}
                <small className="rounded bg-white/10 px-1.5 text-[10px]">{m.fase}</small>
              </span>
            ) : (
              <Link key={m.href} href={m.href} className="block rounded-md px-3 py-2 hover:bg-white/10">
                {m.label}
              </Link>
            ),
          )}
        </nav>
        <div className="mt-auto border-t border-white/10 pt-4 text-sm">
          <div className="truncate font-semibold">{tenantNome}</div>
          <div className="truncate text-xs text-white/60">
            {user.email} · {NOME_PAPEL[papel]}
          </div>
          <form action={sair}>
            <button className="mt-3 w-full rounded-md border border-white/20 py-1.5 text-xs hover:bg-white/10">
              Sair
            </button>
          </form>
        </div>
      </aside>
      <main className="min-w-0 flex-1 p-8">{children}</main>
    </div>
  );
}
