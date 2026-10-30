-- ══════════════════════════════════════════════════════════════════
-- INVENTARIOS · FASE 0 · ANTES DEL CONTEO DE REINICIO (31 oct – 5 nov 2026)
--
-- 1. Falda bolero = una sola referencia.
--    FALDA CORTA DE BAÑO y FALDA LARGA DE BAÑO son la misma prenda (ANT3051, falda de
--    boleros). Feria reporta todas las ventas como FALDA CORTA DE BAÑO, así que la larga
--    nunca se descontaba. Se unen con un alias: LARGA → CORTA. El nombre visible se
--    queda como FALDA CORTA DE BAÑO: renombrarla tocaría bodega, iniciales, conteos,
--    despachos, ventas, costos e insumos con historia, y no es para hacerlo un día
--    antes de contar.
--
--    IMPORTANTE: pegar DESPUÉS de publicar el index.html de esta fase. El motor de
--    inventario de antes, al unir dos nombres en uno, se quedaba con una sola de las
--    dos cifras (6 a 13 unidades de falda por local). El nuevo las suma.
--
-- 2. Momento del conteo: 'apertura' o 'cierre'. Los conteos existentes quedan como
--    'cierre'.
--
-- Solo aditivo, salvo re-apuntar el alias FALDA LARGA BOLERO (que hoy va a FALDA LARGA
-- DE BAÑO): no se permiten cadenas de alias. El orden de las sentencias importa.
-- ══════════════════════════════════════════════════════════════════

-- ─── 1 · Falda bolero ─────────────────────────────────────────────
-- primero el alias viejo, para que FALDA LARGA DE BAÑO deje de ser destino
UPDATE public.referencia_alias SET referencia = 'FALDA CORTA DE BAÑO'
 WHERE alias = 'FALDA LARGA BOLERO';

INSERT INTO public.referencia_alias (alias, referencia)
VALUES ('FALDA LARGA DE BAÑO', 'FALDA CORTA DE BAÑO')
ON CONFLICT (alias) DO UPDATE SET referencia = EXCLUDED.referencia;

-- Las variantes de la larga quedan como descontinuadas (no se borran: tienen historia).
UPDATE public.variantes SET descontinuado = true
 WHERE referencia IN ('FALDA LARGA DE BAÑO', 'FALDA LARGA BOLERO');

-- ─── 2 · Momento del conteo ──────────────────────────────────────
ALTER TABLE public.conteos_fisicos
  ADD COLUMN IF NOT EXISTS momento text NOT NULL DEFAULT 'cierre';
ALTER TABLE public.conteos_fisicos DROP CONSTRAINT IF EXISTS conteos_fisicos_momento_chk;
ALTER TABLE public.conteos_fisicos
  ADD CONSTRAINT conteos_fisicos_momento_chk CHECK (momento IN ('apertura', 'cierre'));

COMMENT ON COLUMN public.conteos_fisicos.momento IS
  'Si se contó al abrir la tienda (vale como saldo al cierre del día anterior) o al cerrar.';

-- ─── Comprobación ─────────────────────────────────────────────────
SELECT alias, referencia FROM public.referencia_alias
 WHERE referencia = 'FALDA CORTA DE BAÑO' ORDER BY alias;
-- Esperado: FALDA BOLEROS · FALDA CORTA BOLERO · FALDA LARGA BOLERO · FALDA LARGA DE BAÑO
--           · FALDA MALLA VELO SURTIDA  (todas → FALDA CORTA DE BAÑO)

SELECT momento, count(*) FROM public.conteos_fisicos GROUP BY momento;
-- Esperado: cierre · 11

-- ══════════════════════════════════════════════════════════════════
-- ROLLBACK
--   DELETE FROM public.referencia_alias WHERE alias = 'FALDA LARGA DE BAÑO';
--   UPDATE public.referencia_alias SET referencia = 'FALDA LARGA DE BAÑO' WHERE alias = 'FALDA LARGA BOLERO';
--   UPDATE public.variantes SET descontinuado = false WHERE referencia IN ('FALDA LARGA DE BAÑO','FALDA LARGA BOLERO');
--   ALTER TABLE public.conteos_fisicos DROP CONSTRAINT IF EXISTS conteos_fisicos_momento_chk;
--   ALTER TABLE public.conteos_fisicos DROP COLUMN IF EXISTS momento;
-- ══════════════════════════════════════════════════════════════════
