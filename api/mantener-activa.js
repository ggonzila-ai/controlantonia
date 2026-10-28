// Mantiene viva la base de datos de Supabase.
//
// El plan gratuito de Supabase pausa el proyecto cuando pasa unos días sin uso, y la
// app queda "Sin conexión" con todo desactualizado (pasó el 28 de octubre de 2026).
// Vercel llama esta función una vez al día (ver "crons" en vercel.json) y una consulta
// mínima basta para que el proyecto cuente como en uso.
//
// La llave es la pública (anon), la misma que ya está en index.html: solo lee.
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://ptdmrbwapyxhigcwhati.supabase.co';
const SUPABASE_KEY = process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB0ZG1yYndhcHl4aGlnY3doYXRpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwNDQ0NzcsImV4cCI6MjA5NjYyMDQ3N30.eTEVFZWLfQBQYqFuZS1PkJmuOkG1deDt461vTJ4nvLU';

module.exports = async (req, res) => {
  const inicio = Date.now();
  try {
    const r = await fetch(SUPABASE_URL + '/rest/v1/almacenes?select=id&limit=1', {
      headers: { apikey: SUPABASE_KEY, Authorization: 'Bearer ' + SUPABASE_KEY }
    });
    res.status(r.ok ? 200 : 502).json({ ok: r.ok, supabase: r.status, ms: Date.now() - inicio });
  } catch (e) {
    res.status(502).json({ ok: false, error: String(e && e.message || e), ms: Date.now() - inicio });
  }
};
