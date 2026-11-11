import { getContexto } from "@/lib/contexto";

export default async function PainelPage() {
  const { supabase, tenantId, tenantNome } = await getContexto();

  const contar = async (tabela: string, filtro?: [string, string]) => {
    let q = supabase.from(tabela).select("*", { count: "exact", head: true }).eq("tenant_id", tenantId);
    if (filtro) q = q.eq(filtro[0], filtro[1]);
    const { count } = await q;
    return count ?? 0;
  };

  const [empresas, ghes, riscos, atrasadas] = await Promise.all([
    contar("companies"),
    contar("ghes"),
    contar("ghe_risks"),
    contar("action_items_status", ["effective_status", "atrasada"]),
  ]);

  const cards = [
    { n: empresas, l: "Empresas atendidas" },
    { n: ghes, l: "GHE cadastrados" },
    { n: riscos, l: "Riscos inventariados" },
    { n: atrasadas, l: "Ações atrasadas", alerta: atrasadas > 0 },
  ];

  return (
    <>
      <h1 className="text-2xl font-bold">Painel</h1>
      <p className="mb-6 text-slate-500">{tenantNome}</p>

      <div className="mb-6 grid grid-cols-2 gap-4 lg:grid-cols-4">
        {cards.map((c) => (
          <div key={c.l} className="rounded-xl bg-white p-5 shadow-sm">
            <b className={`block text-3xl ${c.alerta ? "text-red-700" : "text-marca-600"}`}>{c.n}</b>
            <span className="text-sm text-slate-500">{c.l}</span>
          </div>
        ))}
      </div>

      <div className="rounded-xl bg-white p-6 shadow-sm">
        <h2 className="mb-3 font-semibold">Fase 0 concluída</h2>
        <p className="text-sm text-slate-600">
          Login, conta da consultoria e isolamento de dados estão funcionando. Os próximos módulos aparecem no menu
          conforme forem liberados: cadastro de empresas e estrutura (Fase 1), inventário de riscos (Fase 2) e plano
          de ação com PGR (Fase 3).
        </p>
      </div>
    </>
  );
}
