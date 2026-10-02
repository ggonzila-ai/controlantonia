-- ══════════════════════════════════════════════════════════════════
-- PENDIENTES · pegar completo en Supabase → SQL Editor y dar Run
-- Son tres cambios en orden: precio del catálogo, nombres de blusas,
-- y el precio que alimenta el punto de equilibrio.
-- Ninguno mueve saldos históricos.
-- ══════════════════════════════════════════════════════════════════

-- ══════════════════════════════════════════════════════════════════
-- ACTUALIZACIÓN DE PRECIOS · 2026-09-29
--
-- Laura pasó seis precios. Cinco ya coincidían con el catálogo cargado el 18 de
-- septiembre, así que solo cambia uno:
--
--   PIJAMA CAPRI VERA (ANT5302)        52.900 → 55.900   ← único cambio
--   CAPRI LICRA ALGODÓN (ANT8153)      52.900   ya estaba  (= capri de bolsillos)
--   SHORT BOLSILLO ALGODON (ANT8164)   44.900   ya estaba
--   SHORT MALLA SURTIDO (ANT3035)      32.900   ya estaba  (= short de baño)
--   BLUSA GEA EN DURAZNO (ANT6301)     39.900   ya estaba
--   PANTALON BLONDA ENCAJE (ANT3030)   48.900   ya estaba  (= pantalón de baño)
--
-- Se actualizan el producto y todas sus tallas, que llevan el precio repetido.
-- NO se toca ventas.precio_unitario: cada venta conserva el precio al que se vendió.
-- ══════════════════════════════════════════════════════════════════

BEGIN;

CREATE TABLE IF NOT EXISTS respaldo_precios_20260929 AS
  SELECT id, referencia_base, nombre, precio_venta, now() AS guardado_en
    FROM productos WHERE false;
TRUNCATE respaldo_precios_20260929;
INSERT INTO respaldo_precios_20260929
  SELECT id, referencia_base, nombre, precio_venta, now() FROM productos;

UPDATE productos
   SET precio_venta = 55900, updated_at = now()
 WHERE referencia_base = 'ANT5302';

UPDATE productos_variantes v
   SET precio_venta = 55900
  FROM productos p
 WHERE p.id = v.producto_id AND p.referencia_base = 'ANT5302';

-- Comprobación: el precio del producto y el de todas sus tallas deben ir juntos.
SELECT p.referencia_base, p.nombre, p.precio_venta,
       count(v.id) AS tallas, array_agg(DISTINCT v.precio_venta) AS precios_tallas
  FROM productos p LEFT JOIN productos_variantes v ON v.producto_id = p.id
 WHERE p.referencia_base IN ('ANT5302','ANT8153','ANT8164','ANT3035','ANT6301','ANT3030')
 GROUP BY p.referencia_base, p.nombre, p.precio_venta
 ORDER BY p.referencia_base;
-- Esperado: ANT5302 → 55900 en el producto y en sus 6 tallas; los otros cinco sin cambio.

COMMIT;

-- ROLLBACK:
--   UPDATE productos p SET precio_venta = r.precio_venta
--     FROM respaldo_precios_20260929 r WHERE r.id = p.id;
--   UPDATE productos_variantes v SET precio_venta = p.precio_venta
--     FROM productos p WHERE p.id = v.producto_id AND p.referencia_base = 'ANT5302';

-- ══════════════════════════════════════════════════════════════════
-- 1 · "BLUSA DURAZNO 36900" pasa a llamarse "BLUSA GEA EN DURAZNO"
-- 2 · La blusa combinada se separa en dos, DE AHORA EN ADELANTE
--
-- Decidido por Laura el 2026-09-29.
--
-- El renombrado es solo la etiqueta: cambia el nombre en todas las tablas que lo
-- guardan, y las cantidades quedan idénticas. Se elige un nombre sin precio adentro
-- para no tener que renombrarlo cada vez que suba el precio (ya pasó: el nombre decía
-- 36900 y la prenda vale 39.900). No hay claves foráneas por nombre, así que el orden
-- de los UPDATE no importa.
--
-- La separación sigue el mismo criterio que las batolas siza: se cambia el mapeo para
-- las ventas futuras y NO se mueve el histórico. Las 131 unidades ya registradas se
-- quedan en "BLUSA 39900 & 49900", que sobrevive como referencia histórica.
--
-- ANT6205 (blusa señorera chalís, 1 unidad) se deja apuntando a la combinada: no está
-- en el catálogo activo y no llegarán ventas nuevas con ese código.
-- ══════════════════════════════════════════════════════════════════

BEGIN;

-- ─── 1 · Renombrar el durazno ─────────────────────────────────────
UPDATE bodega              SET referencia='BLUSA GEA EN DURAZNO' WHERE referencia='BLUSA DURAZNO 36900';
UPDATE codigos_sku         SET referencia='BLUSA GEA EN DURAZNO' WHERE referencia='BLUSA DURAZNO 36900';
UPDATE conteo_items        SET referencia='BLUSA GEA EN DURAZNO' WHERE referencia='BLUSA DURAZNO 36900';
UPDATE despacho_items      SET referencia='BLUSA GEA EN DURAZNO' WHERE referencia='BLUSA DURAZNO 36900';
UPDATE inventario_apertura SET referencia='BLUSA GEA EN DURAZNO' WHERE referencia='BLUSA DURAZNO 36900';
UPDATE referencia_alias    SET referencia='BLUSA GEA EN DURAZNO' WHERE referencia='BLUSA DURAZNO 36900';
UPDATE referencia_costos   SET referencia='BLUSA GEA EN DURAZNO' WHERE referencia='BLUSA DURAZNO 36900';
UPDATE referencia_insumos  SET referencia='BLUSA GEA EN DURAZNO' WHERE referencia='BLUSA DURAZNO 36900';
UPDATE variantes           SET referencia='BLUSA GEA EN DURAZNO' WHERE referencia='BLUSA DURAZNO 36900';
UPDATE ventas              SET referencia='BLUSA GEA EN DURAZNO' WHERE referencia='BLUSA DURAZNO 36900';
UPDATE productos           SET referencia_inventario='BLUSA GEA EN DURAZNO' WHERE referencia_inventario='BLUSA DURAZNO 36900';
-- Los respaldo_* se dejan con el nombre viejo a propósito: son fotos del pasado.

-- ─── 2 · Separar las dos blusas, hacia adelante ───────────────────
INSERT INTO bodega (referencia, categoria, stock, costo)
SELECT 'BLUSA JUVENIL VELO', 'BLUSAS', 0, 0
 WHERE NOT EXISTS (SELECT 1 FROM bodega WHERE referencia='BLUSA JUVENIL VELO');
INSERT INTO bodega (referencia, categoria, stock, costo)
SELECT 'BLUSA DE MODA CHALIS HINDU', 'BLUSAS', 0, 0
 WHERE NOT EXISTS (SELECT 1 FROM bodega WHERE referencia='BLUSA DE MODA CHALIS HINDU');

UPDATE codigos_sku SET referencia='BLUSA JUVENIL VELO'         WHERE codigo='ANT2001';
UPDATE codigos_sku SET referencia='BLUSA DE MODA CHALIS HINDU' WHERE codigo='ANT6215';

-- Sin esto, una fila que diga "BLUSA DE MODA" volvería a caer en la combinada al leerse.
UPDATE referencia_alias SET referencia='BLUSA DE MODA CHALIS HINDU'
 WHERE alias='BLUSA DE MODA' AND referencia='BLUSA 39900 & 49900';

UPDATE productos SET referencia_inventario='BLUSA JUVENIL VELO'         WHERE referencia_base='ANT2001';
UPDATE productos SET referencia_inventario='BLUSA DE MODA CHALIS HINDU' WHERE referencia_base='ANT6215';

-- ─── Comprobación ─────────────────────────────────────────────────
SELECT 'quedan con el nombre viejo' AS control,
       (SELECT count(*) FROM ventas WHERE referencia='BLUSA DURAZNO 36900') AS ventas,
       (SELECT count(*) FROM conteo_items WHERE referencia='BLUSA DURAZNO 36900') AS conteos,
       (SELECT count(*) FROM inventario_apertura WHERE referencia='BLUSA DURAZNO 36900') AS inicial,
       (SELECT count(*) FROM bodega WHERE referencia='BLUSA DURAZNO 36900') AS bodega;
-- Esperado: todo en 0.

SELECT referencia, count(*) filas, coalesce(sum(cantidad),0) uds
  FROM ventas WHERE referencia IN ('BLUSA GEA EN DURAZNO','BLUSA 39900 & 49900',
                                   'BLUSA JUVENIL VELO','BLUSA DE MODA CHALIS HINDU')
 GROUP BY referencia ORDER BY referencia;
-- Esperado: BLUSA GEA EN DURAZNO 96 filas / 102 uds  ·  BLUSA 39900 & 49900 124 / 131
--           las dos nuevas sin ventas todavía (el histórico no se mueve).

SELECT codigo, referencia FROM codigos_sku
 WHERE codigo IN ('ANT2001','ANT6215','ANT6205','ANT6201','ANT6301') ORDER BY codigo;
-- Esperado: ANT2001 → BLUSA JUVENIL VELO · ANT6215 → BLUSA DE MODA CHALIS HINDU
--           ANT6205 → BLUSA 39900 & 49900 (se queda) · ANT6201 y ANT6301 → BLUSA GEA EN DURAZNO

COMMIT;

-- ══════════════════════════════════════════════════════════════════
-- ROLLBACK (deshace ambas cosas):
--   UPDATE bodega SET referencia='BLUSA DURAZNO 36900' WHERE referencia='BLUSA GEA EN DURAZNO';
--   UPDATE codigos_sku SET referencia='BLUSA DURAZNO 36900' WHERE referencia='BLUSA GEA EN DURAZNO';
--   UPDATE conteo_items SET referencia='BLUSA DURAZNO 36900' WHERE referencia='BLUSA GEA EN DURAZNO';
--   UPDATE despacho_items SET referencia='BLUSA DURAZNO 36900' WHERE referencia='BLUSA GEA EN DURAZNO';
--   UPDATE inventario_apertura SET referencia='BLUSA DURAZNO 36900' WHERE referencia='BLUSA GEA EN DURAZNO';
--   UPDATE referencia_alias SET referencia='BLUSA DURAZNO 36900' WHERE referencia='BLUSA GEA EN DURAZNO';
--   UPDATE referencia_costos SET referencia='BLUSA DURAZNO 36900' WHERE referencia='BLUSA GEA EN DURAZNO';
--   UPDATE referencia_insumos SET referencia='BLUSA DURAZNO 36900' WHERE referencia='BLUSA GEA EN DURAZNO';
--   UPDATE variantes SET referencia='BLUSA DURAZNO 36900' WHERE referencia='BLUSA GEA EN DURAZNO';
--   UPDATE ventas SET referencia='BLUSA DURAZNO 36900' WHERE referencia='BLUSA GEA EN DURAZNO';
--   UPDATE productos SET referencia_inventario='BLUSA DURAZNO 36900' WHERE referencia_inventario='BLUSA GEA EN DURAZNO';
--   UPDATE codigos_sku SET referencia='BLUSA 39900 & 49900' WHERE codigo IN ('ANT2001','ANT6215');
--   UPDATE referencia_alias SET referencia='BLUSA 39900 & 49900' WHERE alias='BLUSA DE MODA';
--   UPDATE productos SET referencia_inventario='BLUSA 39900 & 49900' WHERE referencia_base IN ('ANT2001','ANT6215');
--   DELETE FROM bodega WHERE referencia IN ('BLUSA JUVENIL VELO','BLUSA DE MODA CHALIS HINDU') AND stock=0;
-- ══════════════════════════════════════════════════════════════════

-- ══════════════════════════════════════════════════════════════════
-- SHORTS DE BOLSILLO: 42.900 → 44.900 en la tabla que alimenta el PE
--
-- El punto de equilibrio NO usa los precios del catálogo (productos), sino
-- referencia_costos.precio_venta, que va por nombre de inventario. De los seis
-- precios que pasó Laura, cinco ya estaban al día ahí; este era el único viejo,
-- y por eso el break-even salía con un margen más bajo del real.
-- ══════════════════════════════════════════════════════════════════
BEGIN;
UPDATE referencia_costos SET precio_venta = 44900 WHERE referencia = 'SHORTS DE BOLSILLO';

SELECT referencia, precio_venta FROM referencia_costos
 WHERE referencia IN ('SHORTS DE BOLSILLO','CAPRI DE BOLSILLO','SHORTS DE BAÑO',
                      'PIJAMA CAPRI VERA','PANTALONES DE BAÑO','BLUSA GEA EN DURAZNO')
 ORDER BY referencia;
-- Esperado: 44900 · 52900 · 32900 · 55900 · 48900 · 39900
COMMIT;
-- ROLLBACK:  UPDATE referencia_costos SET precio_venta=42900 WHERE referencia='SHORTS DE BOLSILLO';
