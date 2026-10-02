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
