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
