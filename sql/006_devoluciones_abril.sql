-- ══════════════════════════════════════════════════════════════════
-- LAS 5 DEVOLUCIONES DE ABRIL QUE NUNCA SE CARGARON
--
-- Abril es el ÚNICO mes sin devoluciones en la base: enero 3, febrero 4, marzo 2,
-- mayo 7, junio 2, julio 4, agosto 3 … y abril 0. El reporte "VENTA 01 AL 26.xlsx"
-- sí las trae: cinco filas con cantidad −1, una por día (13, 15, 16, 21 y 25).
-- Se perdieron al cargar el mes, antes de que el parser aprendiera a leerlas.
--
-- Resultado: abril está inflado en 5 unidades (la base dice 473, el reporte 468).
--
-- Cada devolución se carga con la MISMA referencia que sus hermanas de abril, para
-- que cancele contra la venta que revierte y no cree un saldo fantasma:
--   ANT5177 y ANT5022 → BATOLA SIZA BOLSILLO   (así se cargó abril)
--   ANT5117           → PIJAMA DE SHORT NOA
--   ANT6201           → BLUSA 39900 & 49900     (en abril se cargó ahí, no al durazno)
--   ANT5010           → BATOLA TIRAS
-- Convención de la tabla: cantidad negativa, precio_unitario positivo, total negativo.
-- ══════════════════════════════════════════════════════════════════

BEGIN;

INSERT INTO ventas (fecha, almacen_id, almacen_nombre, referencia, categoria,
                    talla, codigo, cantidad, precio_unitario, total, descuento, periodo)
SELECT v.fecha::date,
       a.id,
       a.nombre,
       v.referencia,
       coalesce((SELECT b.categoria FROM bodega b WHERE b.referencia = v.referencia LIMIT 1), 'PIJAMERIA'),
       v.talla, v.codigo, -1, v.precio, -v.precio, 0, '2026-04'
  FROM (VALUES
    ('2026-04-13','Feria del Brasier Malca 2',             'BATOLA SIZA BOLSILLO','2XL','ANT51772XL2600',39900),
    ('2026-04-15','Feria del Brasier Cra 8',               'BATOLA SIZA BOLSILLO','3XL','ANT50223XL2600',39900),
    ('2026-04-16','Feria del Brasier Outlet Íntimo Cra 1', 'PIJAMA DE SHORT NOA',  'M', 'ANT5117M2600',  37900),
    ('2026-04-21','Feria del Brasier Outlet Íntimo Cra 1', 'BLUSA 39900 & 49900',  'XL','ANT6201XL2600', 36900),
    ('2026-04-25','Feria del Brasier Outlet Íntimo Cra 1', 'BATOLA TIRAS',         'XL','ANT5010XL2600', 32900)
  ) AS v(fecha, almacen, referencia, talla, codigo, precio)
  JOIN almacenes a ON a.nombre = v.almacen
 WHERE NOT EXISTS (                       -- idempotente: si ya se corrió, no duplica
   SELECT 1 FROM ventas x
    WHERE x.fecha = v.fecha::date AND x.codigo = v.codigo AND x.cantidad = -1);

-- ─── Comprobación ─────────────────────────────────────────────────
SELECT count(*) AS devoluciones_abril, coalesce(sum(cantidad),0) AS uds
  FROM ventas WHERE periodo = '2026-04' AND cantidad < 0;
-- Esperado: 5 devoluciones · −5 uds

SELECT sum(cantidad) AS uds_abril, count(*) AS filas FROM ventas WHERE periodo = '2026-04';
-- Esperado: 468 uds / 401 filas — igual que el reporte de Feria

COMMIT;

-- ROLLBACK:
--   DELETE FROM ventas WHERE periodo='2026-04' AND cantidad < 0;
