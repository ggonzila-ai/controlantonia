-- ══════════════════════════════════════════════════════════════════
-- FASE 4 · ASIGNAR CÓDIGOS DE BARRAS A LAS TALLAS PENDIENTES
--
-- GS1 asigna los códigos DESPUÉS de registrar el producto, así que una referencia nace
-- con tallas sin código ("pendiente GS1") y los códigos llegan luego. Estas dos
-- funciones son la puerta de entrada:
--
--   asignar_codigo_barras()  una talla, escaneando o digitando
--   asignar_codigos_lote()   varias de una vez, pegando la lista que entrega GS1
--
-- Las validaciones viven aquí y no solo en la pantalla: dígito de control, prefijo de
-- Antonia y que el código no sea ya de otra talla.
-- ══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.asignar_codigo_barras(p_variante_id uuid, p_codigo text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE v_cod text := nullif(btrim(coalesce(p_codigo,'')),''); v_dueno text; v_ref text; v_talla text;
BEGIN
  SELECT pr.referencia_base, pv.talla INTO v_ref, v_talla
    FROM productos_variantes pv JOIN productos pr ON pr.id = pv.producto_id
   WHERE pv.id = p_variante_id;
  IF v_ref IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'motivo', 'Esa talla no existe');
  END IF;

  -- Quitar el código: la talla vuelve a quedar pendiente de GS1.
  IF v_cod IS NULL THEN
    UPDATE productos_variantes SET codigo_barras = NULL, estado_codigo = 'pendiente_gs1'
     WHERE id = p_variante_id;
    RETURN jsonb_build_object('ok', true, 'referencia', v_ref, 'talla', v_talla,
                              'estado', 'pendiente_gs1');
  END IF;

  IF NOT ean13_valido(v_cod) THEN
    RETURN jsonb_build_object('ok', false, 'motivo',
      'El código ' || v_cod || ' no es un EAN-13 válido (dígito de control incorrecto)');
  END IF;
  IF v_cod NOT LIKE '7706730%' THEN
    RETURN jsonb_build_object('ok', false, 'motivo',
      'El código ' || v_cod || ' no empieza por 7706730, que es el prefijo de Antonia');
  END IF;

  SELECT pr.referencia_base || ' – talla ' || pv.talla INTO v_dueno
    FROM productos_variantes pv JOIN productos pr ON pr.id = pv.producto_id
   WHERE pv.codigo_barras = v_cod AND pv.id <> p_variante_id;
  IF v_dueno IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'motivo', 'Ya pertenece a ' || v_dueno);
  END IF;

  UPDATE productos_variantes
     SET codigo_barras = v_cod, estado_codigo = 'asignado'
   WHERE id = p_variante_id;

  RETURN jsonb_build_object('ok', true, 'referencia', v_ref, 'talla', v_talla,
                            'codigo', v_cod, 'estado', 'asignado');
END $fn$;

-- Lote: [{"referencia_base":"ANT5010","talla":"M","codigo":"7706730..."}, …]
-- Se valida TODO antes de escribir: o entran todas o no entra ninguna, para no quedar
-- con media lista aplicada y sin saber dónde se cortó.
CREATE OR REPLACE FUNCTION public.asignar_codigos_lote(p jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE
  r jsonb; v_cod text; v_base text; v_talla text; v_id uuid; v_dueno text;
  v_errores jsonb := '[]'::jsonb; v_ok jsonb := '[]'::jsonb; v_vistos text[] := '{}';
  v_n int := 0;
BEGIN
  -- ── Revisión completa, sin escribir ──
  FOR r IN SELECT jsonb_array_elements(coalesce(p->'filas','[]'::jsonb)) LOOP
    v_base  := upper(btrim(coalesce(r->>'referencia_base','')));
    v_talla := upper(btrim(coalesce(r->>'talla','')));
    v_cod   := nullif(btrim(coalesce(r->>'codigo','')),'');

    SELECT pv.id INTO v_id FROM productos_variantes pv
      JOIN productos pr ON pr.id = pv.producto_id
     WHERE pr.referencia_base = v_base AND upper(pv.talla) = v_talla;

    IF v_id IS NULL THEN
      v_errores := v_errores || jsonb_build_array(v_base || ' talla ' || v_talla || ': no existe esa talla');
    ELSIF v_cod IS NULL THEN
      v_errores := v_errores || jsonb_build_array(v_base || ' talla ' || v_talla || ': sin código');
    ELSIF NOT ean13_valido(v_cod) THEN
      v_errores := v_errores || jsonb_build_array(v_cod || ': dígito de control incorrecto');
    ELSIF v_cod NOT LIKE '7706730%' THEN
      v_errores := v_errores || jsonb_build_array(v_cod || ': no empieza por 7706730');
    ELSIF v_cod = ANY (v_vistos) THEN
      v_errores := v_errores || jsonb_build_array(v_cod || ': repetido dentro de la lista');
    ELSE
      SELECT pr.referencia_base || ' – talla ' || pv.talla INTO v_dueno
        FROM productos_variantes pv JOIN productos pr ON pr.id = pv.producto_id
       WHERE pv.codigo_barras = v_cod AND pv.id <> v_id;
      IF v_dueno IS NOT NULL THEN
        v_errores := v_errores || jsonb_build_array(v_cod || ': ya pertenece a ' || v_dueno);
      ELSE
        v_vistos := array_append(v_vistos, v_cod);
        v_ok := v_ok || jsonb_build_array(jsonb_build_object('id', v_id, 'codigo', v_cod,
                  'etiqueta', v_base || ' – talla ' || v_talla));
      END IF;
    END IF;
  END LOOP;

  IF jsonb_array_length(v_errores) > 0 THEN
    RETURN jsonb_build_object('ok', false, 'asignados', 0,
      'errores', v_errores, 'revisados', jsonb_array_length(v_ok) + jsonb_array_length(v_errores));
  END IF;

  -- ── Aplicar ──
  FOR r IN SELECT jsonb_array_elements(v_ok) LOOP
    UPDATE productos_variantes
       SET codigo_barras = r->>'codigo', estado_codigo = 'asignado'
     WHERE id = (r->>'id')::uuid;
    v_n := v_n + 1;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'asignados', v_n, 'errores', '[]'::jsonb);
END $fn$;

GRANT EXECUTE ON FUNCTION public.asignar_codigo_barras(uuid, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.asignar_codigos_lote(jsonb) TO anon, authenticated;

-- ─── Vista de pendientes, para la pantalla y para la alerta de Inicio ───
CREATE OR REPLACE VIEW public.v_codigos_pendientes AS
SELECT pv.id AS variante_id, pr.id AS producto_id, pr.referencia_base, pr.nombre,
       pr.categoria, pv.talla, pr.desc_larga, pr.desc_corta, pr.tipo_inventario
  FROM productos_variantes pv
  JOIN productos pr ON pr.id = pv.producto_id
 WHERE pv.estado_codigo = 'pendiente_gs1' AND pv.activo AND pr.activo;

GRANT SELECT ON public.v_codigos_pendientes TO anon, authenticated;

-- ─── Comprobación ─────────────────────────────────────────────────
SELECT count(*) AS tallas_pendientes FROM v_codigos_pendientes;
-- Hoy debería ser 0: las 143 variantes del catálogo tienen código.

SELECT asignar_codigo_barras('00000000-0000-0000-0000-000000000000','7706730455433')->>'motivo' AS talla_inexistente,
       (asignar_codigos_lote('{"filas":[{"referencia_base":"ANT8062","talla":"M","codigo":"7706730455433"}]}'::jsonb)->'errores')->>0 AS codigo_de_otra_talla;
-- Esperado: 'Esa talla no existe' · 'ya pertenece a ANT5302 – talla M'
