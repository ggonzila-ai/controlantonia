-- ══════════════════════════════════════════════════════════════════
-- 019 · "CAPRI LICRA ALGODÓN" es CAPRI DE BOLSILLO
--
-- Confirmado por Laura el 19 nov 2026: es la misma prenda. Feria factura ANT8153 con la
-- descripción "CAPRI LICRA ALGODÓN" y codigos_sku ya la manda a CAPRI DE BOLSILLO. El
-- alias cubre las filas que se lean por descripción. Ninguna tabla guarda ese nombre
-- (ventas, despachos, conteos, inventario inicial, ajustes, bodega: 0 filas), así que no
-- mueve ningún saldo. YA APLICADO por la API ese día; este archivo es el registro.
-- ══════════════════════════════════════════════════════════════════

INSERT INTO referencia_alias (alias, referencia, codigo_base, origen, confirmado_por, nota)
SELECT 'CAPRI LICRA ALGODÓN', 'CAPRI DE BOLSILLO', 'ANT8153', 'feria', 'Laura',
       'Misma prenda: Feria factura ANT8153 como capri licra algodón (19 nov 2026)'
 WHERE NOT EXISTS (SELECT 1 FROM referencia_alias WHERE alias = 'CAPRI LICRA ALGODÓN');

-- Comprobación: 1 fila → CAPRI DE BOLSILLO
SELECT alias, referencia FROM referencia_alias WHERE alias = 'CAPRI LICRA ALGODÓN';

-- ROLLBACK:
--   DELETE FROM referencia_alias WHERE alias = 'CAPRI LICRA ALGODÓN';
