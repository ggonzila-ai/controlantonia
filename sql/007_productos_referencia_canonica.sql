-- ══════════════════════════════════════════════════════════════════
-- FASE 2 · `productos` pasa a ser la referencia canónica
--          `productos_variantes` pasa a ser la talla, con su código de barras
--
-- TODO ES ADITIVO. No borra ni renombra nada: `bodega`, el modal viejo, los conteos,
-- las ventas y los despachos siguen funcionando igual mientras se migra.
--
-- Qué agrega:
--   · A la referencia: tipo de inventario, stock mínimo, precio neto Kukos, activo y
--     la ficha Kukos (descripciones y los 5 criterios).
--   · A la talla: estado del código (Pendiente GS1 / Asignado), activo y precio_override.
--   · Dos catálogos que hoy serían listas fijas en el código: tipos de inventario con
--     su curva de tallas, y criterios Kukos. Se llenan desde el Excel en la Fase 5.
--
-- Reglas que quedan exigidas por la base, no solo por la interfaz:
--   · Un EAN-13 no puede estar en dos tallas (ya era único; ahora además valida formato).
--   · Una talla no se repite dentro de una referencia.
--   · Las descripciones Kukos no pasan de 40 y 11 caracteres.
-- ══════════════════════════════════════════════════════════════════

BEGIN;

-- ─── Referencia ───────────────────────────────────────────────────
ALTER TABLE public.productos
  ADD COLUMN IF NOT EXISTS tipo_inventario   TEXT    NOT NULL DEFAULT 'INV002',
  ADD COLUMN IF NOT EXISTS stock_minimo      INTEGER NOT NULL DEFAULT 10,
  ADD COLUMN IF NOT EXISTS precio_neto_kukos INTEGER,
  ADD COLUMN IF NOT EXISTS activo            BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS desc_larga        TEXT,
  ADD COLUMN IF NOT EXISTS desc_corta        TEXT,
  ADD COLUMN IF NOT EXISTS k_linea           TEXT,
  ADD COLUMN IF NOT EXISTS k_genero          TEXT,
  ADD COLUMN IF NOT EXISTS k_componente      TEXT,
  ADD COLUMN IF NOT EXISTS k_silueta         TEXT,
  ADD COLUMN IF NOT EXISTS k_uso             TEXT;

COMMENT ON COLUMN public.productos.precio_neto_kukos IS
  'Precio neto que paga Kukos por unidad, SIN IVA. NO es costo de producción: nunca debe entrar al módulo de Costos/Rentabilidad. Viene de la columna COSTO SIN IVA del Excel de codificación.';
COMMENT ON COLUMN public.productos.tipo_inventario IS
  'Curva de tallas: INV001 numérica 26-48, INV002 alfanumérica U y XXS-7XL, INV003 junior, INV004 bebés, INV005 medias.';

ALTER TABLE public.productos
  DROP CONSTRAINT IF EXISTS productos_desc_larga_len,
  DROP CONSTRAINT IF EXISTS productos_desc_corta_len;
ALTER TABLE public.productos
  ADD CONSTRAINT productos_desc_larga_len CHECK (desc_larga IS NULL OR char_length(desc_larga) <= 40),
  ADD CONSTRAINT productos_desc_corta_len CHECK (desc_corta IS NULL OR char_length(desc_corta) <= 11);

-- ─── Variante (una por talla) ─────────────────────────────────────
ALTER TABLE public.productos_variantes
  ADD COLUMN IF NOT EXISTS estado_codigo   TEXT    NOT NULL DEFAULT 'asignado',
  ADD COLUMN IF NOT EXISTS activo          BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS precio_override INTEGER;

ALTER TABLE public.productos_variantes DROP CONSTRAINT IF EXISTS pv_estado_codigo_chk;
ALTER TABLE public.productos_variantes
  ADD CONSTRAINT pv_estado_codigo_chk CHECK (estado_codigo IN ('pendiente_gs1','asignado'));

-- El estado se deriva del código: sin código, pendiente de GS1.
UPDATE public.productos_variantes
   SET estado_codigo = CASE WHEN codigo_barras IS NULL OR btrim(codigo_barras) = ''
                            THEN 'pendiente_gs1' ELSE 'asignado' END;

-- Formato del código: 13 dígitos con el prefijo de Antonia.
ALTER TABLE public.productos_variantes DROP CONSTRAINT IF EXISTS pv_codigo_barras_formato;
ALTER TABLE public.productos_variantes
  ADD CONSTRAINT pv_codigo_barras_formato
  CHECK (codigo_barras IS NULL OR codigo_barras ~ '^7706730[0-9]{6}$');

-- Una talla no se repite dentro de una referencia.
CREATE UNIQUE INDEX IF NOT EXISTS pv_producto_talla_uniq
  ON public.productos_variantes (producto_id, talla);

-- ─── Catálogos ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.tipos_inventario (
  codigo     TEXT PRIMARY KEY,
  nombre     TEXT NOT NULL,
  tallas     TEXT[] NOT NULL DEFAULT '{}',
  activo     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.criterios_kukos (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  grupo      TEXT NOT NULL,          -- linea | genero | componente | silueta | uso
  codigo     TEXT NOT NULL,          -- p. ej. '2003-PIJAMAS'
  nombre     TEXT,
  activo     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (grupo, codigo)
);
CREATE INDEX IF NOT EXISTS criterios_kukos_grupo_idx ON public.criterios_kukos (grupo);

ALTER TABLE public.tipos_inventario ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.criterios_kukos  ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tipos_inventario_todo ON public.tipos_inventario;
DROP POLICY IF EXISTS criterios_kukos_todo  ON public.criterios_kukos;
CREATE POLICY tipos_inventario_todo ON public.tipos_inventario FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY criterios_kukos_todo  ON public.criterios_kukos  FOR ALL USING (true) WITH CHECK (true);

-- Tarifas configurables (hoy en el código: IVA 19%, Kukos 16%).
INSERT INTO public.app_config (clave, valor) VALUES ('iva_pct', '19'::jsonb)
  ON CONFLICT (clave) DO NOTHING;
INSERT INTO public.app_config (clave, valor) VALUES ('kukos_pct', '16'::jsonb)
  ON CONFLICT (clave) DO NOTHING;

-- ─── Comprobación ─────────────────────────────────────────────────
SELECT (SELECT count(*) FROM productos)                                                  AS productos,
       (SELECT count(*) FROM productos WHERE activo)                                     AS activos,
       (SELECT count(*) FROM productos_variantes)                                        AS variantes,
       (SELECT count(*) FROM productos_variantes WHERE estado_codigo='asignado')         AS con_codigo,
       (SELECT count(*) FROM productos_variantes WHERE estado_codigo='pendiente_gs1')    AS pendientes_gs1,
       (SELECT count(*) FROM tipos_inventario)                                           AS tipos_inv,
       (SELECT count(*) FROM criterios_kukos)                                            AS criterios;
-- Esperado: 38 productos · 38 activos · 143 variantes · 143 con código · 0 pendientes
--           0 tipos_inv y 0 criterios (se llenan desde el Excel en la Fase 5)

COMMIT;

-- ══════════════════════════════════════════════════════════════════
-- ROLLBACK (quita solo lo que agrega esta migración):
--   DROP TABLE IF EXISTS public.criterios_kukos;
--   DROP TABLE IF EXISTS public.tipos_inventario;
--   DROP INDEX IF EXISTS public.pv_producto_talla_uniq;
--   ALTER TABLE public.productos_variantes
--     DROP CONSTRAINT IF EXISTS pv_codigo_barras_formato,
--     DROP CONSTRAINT IF EXISTS pv_estado_codigo_chk,
--     DROP COLUMN IF EXISTS estado_codigo, DROP COLUMN IF EXISTS activo,
--     DROP COLUMN IF EXISTS precio_override;
--   ALTER TABLE public.productos
--     DROP CONSTRAINT IF EXISTS productos_desc_larga_len,
--     DROP CONSTRAINT IF EXISTS productos_desc_corta_len,
--     DROP COLUMN IF EXISTS tipo_inventario,   DROP COLUMN IF EXISTS stock_minimo,
--     DROP COLUMN IF EXISTS precio_neto_kukos, DROP COLUMN IF EXISTS activo,
--     DROP COLUMN IF EXISTS desc_larga, DROP COLUMN IF EXISTS desc_corta,
--     DROP COLUMN IF EXISTS k_linea, DROP COLUMN IF EXISTS k_genero,
--     DROP COLUMN IF EXISTS k_componente, DROP COLUMN IF EXISTS k_silueta,
--     DROP COLUMN IF EXISTS k_uso;
--   DELETE FROM public.app_config WHERE clave IN ('iva_pct','kukos_pct');
-- ══════════════════════════════════════════════════════════════════
