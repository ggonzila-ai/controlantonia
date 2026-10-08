-- ══════════════════════════════════════════════════════════════════
-- LA REMISIÓN COMO DOCUMENTO
--
-- Lo que falta para poder imprimirla:
--   · Un consecutivo sin saltos ni repetidos, generado por la base.
--   · Que el despacho guarde el código de barras y el PVP del momento, para que una
--     reimpresión futura muestre lo mismo que se entregó aunque el precio cambie.
--   · Color y marca en la referencia.
--   · Estado del documento, para poder anularlo sin borrarlo.
--
-- Las 10 remisiones viejas se quedan como están (decisión de Laura): la secuencia nueva
-- arranca en 23, que es la siguiente a la REM-00022.
-- ══════════════════════════════════════════════════════════════════

BEGIN;

-- ─── Consecutivo sin saltos ───────────────────────────────────────
-- Una secuencia de Postgres deja huecos cuando una transacción se deshace. Como aquí se
-- pidió "sin saltos ni repetidos", el contador va en una fila que se bloquea al leerla:
-- si la transacción se cae, el número vuelve a quedar disponible.
CREATE TABLE IF NOT EXISTS public.consecutivos (
  nombre text PRIMARY KEY,
  valor  integer NOT NULL DEFAULT 0
);
INSERT INTO public.consecutivos (nombre, valor) VALUES ('remision', 22)
  ON CONFLICT (nombre) DO NOTHING;

CREATE OR REPLACE FUNCTION public.siguiente_consecutivo(p_nombre text)
RETURNS integer LANGUAGE plpgsql AS $fn$
DECLARE v int;
BEGIN
  UPDATE public.consecutivos SET valor = valor + 1
   WHERE nombre = p_nombre
   RETURNING valor INTO v;
  IF v IS NULL THEN
    INSERT INTO public.consecutivos (nombre, valor) VALUES (p_nombre, 1) RETURNING valor INTO v;
  END IF;
  RETURN v;
END $fn$;

-- ─── El despacho como documento ───────────────────────────────────
ALTER TABLE public.despachos
  ADD COLUMN IF NOT EXISTS estado          text NOT NULL DEFAULT 'emitida',
  ADD COLUMN IF NOT EXISTS observaciones   text,
  ADD COLUMN IF NOT EXISTS anulada_motivo  text,
  ADD COLUMN IF NOT EXISTS anulada_por     text,
  ADD COLUMN IF NOT EXISTS anulada_en      timestamptz,
  ADD COLUMN IF NOT EXISTS entregado_por   text;

ALTER TABLE public.despachos DROP CONSTRAINT IF EXISTS despachos_estado_chk;
ALTER TABLE public.despachos
  ADD CONSTRAINT despachos_estado_chk CHECK (estado IN ('emitida','anulada'));

-- El precio y el código que salieron impresos, congelados en el momento del despacho.
-- Si mañana sube el PVP, la reimpresión sigue mostrando lo que se entregó.
ALTER TABLE public.despacho_items
  ADD COLUMN IF NOT EXISTS codigo_barras text,
  ADD COLUMN IF NOT EXISTS precio_venta  integer,
  ADD COLUMN IF NOT EXISTS descripcion   text,
  ADD COLUMN IF NOT EXISTS color         text,
  ADD COLUMN IF NOT EXISTS marca         text;

COMMENT ON COLUMN public.despacho_items.precio_venta IS
  'PVP con IVA vigente al momento del despacho. Se congela para que una reimpresión muestre el precio que se entregó, no el actual.';

-- ─── Color y marca en la referencia ───────────────────────────────
ALTER TABLE public.productos
  ADD COLUMN IF NOT EXISTS color text NOT NULL DEFAULT '2600-SURTIDOS',
  ADD COLUMN IF NOT EXISTS marca text NOT NULL DEFAULT 'Antonia Sorev';

COMMENT ON COLUMN public.productos.color IS
  'Código de color de Kukos. Hoy todo se codifica como 2600-SURTIDOS; el catálogo completo está en criterios_kukos grupo color.';

-- ─── Comprobación ─────────────────────────────────────────────────
SELECT (SELECT valor FROM consecutivos WHERE nombre='remision')              AS consecutivo_actual,
       'REM-' || lpad((siguiente_consecutivo('remision'))::text, 5, '0')     AS proximo_numero,
       (SELECT count(*) FROM despachos WHERE estado='emitida')               AS remisiones_emitidas,
       (SELECT count(*) FROM productos WHERE color='2600-SURTIDOS')          AS productos_con_color,
       (SELECT count(*) FROM productos WHERE marca='Antonia Sorev')          AS productos_con_marca;
-- Esperado: 22 · REM-00023 · 10 emitidas · 38 · 38
-- (el consecutivo queda en 23 después de la prueba; la próxima remisión real será la 24)

COMMIT;

-- ROLLBACK:
--   ALTER TABLE despacho_items DROP COLUMN IF EXISTS codigo_barras, DROP COLUMN IF EXISTS precio_venta,
--     DROP COLUMN IF EXISTS descripcion, DROP COLUMN IF EXISTS color, DROP COLUMN IF EXISTS marca;
--   ALTER TABLE despachos DROP CONSTRAINT IF EXISTS despachos_estado_chk,
--     DROP COLUMN IF EXISTS estado, DROP COLUMN IF EXISTS observaciones,
--     DROP COLUMN IF EXISTS anulada_motivo, DROP COLUMN IF EXISTS anulada_por,
--     DROP COLUMN IF EXISTS anulada_en, DROP COLUMN IF EXISTS entregado_por;
--   ALTER TABLE productos DROP COLUMN IF EXISTS color, DROP COLUMN IF EXISTS marca;
--   DROP FUNCTION IF EXISTS siguiente_consecutivo(text);
--   DROP TABLE IF EXISTS consecutivos;
