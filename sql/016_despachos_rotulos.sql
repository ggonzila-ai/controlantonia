-- ══════════════════════════════════════════════════════════════════
-- FASE 3 · RÓTULOS DE CAJA
--
-- Datos nuevos para imprimir un rótulo por caja al final de la remisión:
--   · despachos.cajas: cuántas cajas lleva el envío (por defecto 1).
--   · almacenes: dirección, teléfono, contacto (quién recibe) y notas de entrega.
--
-- Esos datos de los almacenes hoy no existen y no se inventan: quedan vacíos y el
-- rótulo deja la línea en blanco con una raya para escribir a mano. Se llenan desde
-- Almacenes → Datos de entrega.
--
-- Solo aditivo. No toca confirmar_remision, anular_remision ni la lógica de stock.
-- ══════════════════════════════════════════════════════════════════

ALTER TABLE public.despachos
  ADD COLUMN IF NOT EXISTS cajas integer NOT NULL DEFAULT 1;

ALTER TABLE public.despachos DROP CONSTRAINT IF EXISTS despachos_cajas_chk;
ALTER TABLE public.despachos
  ADD CONSTRAINT despachos_cajas_chk CHECK (cajas BETWEEN 1 AND 99);

ALTER TABLE public.almacenes
  ADD COLUMN IF NOT EXISTS direccion     text,
  ADD COLUMN IF NOT EXISTS telefono      text,
  ADD COLUMN IF NOT EXISTS contacto      text,
  ADD COLUMN IF NOT EXISTS notas_entrega text;

COMMENT ON COLUMN public.almacenes.contacto IS 'Quién recibe la mercancía en el local.';
COMMENT ON COLUMN public.almacenes.notas_entrega IS 'Opcional, p. ej. horario de recibo.';

-- ─── Comprobación ─────────────────────────────────────────────────
SELECT (SELECT count(*) FROM despachos WHERE cajas = 1)                 AS despachos_con_1_caja,
       (SELECT count(*) FROM despachos)                                  AS despachos,
       (SELECT count(*) FROM information_schema.columns
         WHERE table_schema='public' AND table_name='almacenes'
           AND column_name IN ('direccion','telefono','contacto','notas_entrega')) AS columnas_nuevas_almacenes;
-- Esperado: 13 · 13 · 4
