-- ══════════════════════════════════════════════════════════════════
-- FASE 3a · GUARDAR UNA REFERENCIA COMPLETA EN UNA SOLA TRANSACCIÓN
--
-- Referencia + tallas + costos + ficha Kukos entran juntos o no entra nada. Si algo
-- falla a mitad, no queda un producto sin tallas ni unas tallas sin producto.
--
-- Escribe en cinco sitios y los deja coherentes:
--   productos             la referencia canónica (código ANT####, PVP, Kukos, ficha)
--   productos_variantes   una fila por talla, con su código de barras o "pendiente GS1"
--   bodega                para que conteos, remisiones y ventas —que van por NOMBRE—
--                         sigan funcionando igual que hoy
--   referencia_costos     el PVP que usa Costos/Rentabilidad y el punto de equilibrio
--   referencia_insumos    los insumos, SIN IVA (ver antonia: el costeo va sin IVA)
--
-- Las validaciones viven aquí, no solo en la pantalla: una referencia repetida, un
-- EAN-13 con dígito de control malo o un código que ya es de otra talla se rechazan
-- aunque alguien llame la RPC por fuera de la app.
-- ══════════════════════════════════════════════════════════════════

-- ─── Un nombre no se repite en bodega ─────────────────────────────
-- `bodega` solo tenía PK por id, así que la base permitía dos productos con el mismo
-- nombre — y el resto de la app identifica el producto por su nombre, de modo que dos
-- homónimos mezclarían stock, conteos y ventas. Hoy no hay ninguno repetido (verificado),
-- así que se puede cerrar.
CREATE UNIQUE INDEX IF NOT EXISTS bodega_referencia_uniq ON public.bodega (referencia);

-- ─── Dígito de control de un EAN-13 ───────────────────────────────
CREATE OR REPLACE FUNCTION public.ean13_valido(p_codigo text)
RETURNS boolean LANGUAGE plpgsql IMMUTABLE AS $fn$
DECLARE s int := 0; i int; d int;
BEGIN
  IF p_codigo IS NULL OR p_codigo !~ '^[0-9]{13}$' THEN RETURN false; END IF;
  FOR i IN 1..12 LOOP
    d := substr(p_codigo, i, 1)::int;
    s := s + d * CASE WHEN i % 2 = 1 THEN 1 ELSE 3 END;
  END LOOP;
  RETURN ((10 - (s % 10)) % 10) = substr(p_codigo, 13, 1)::int;
END $fn$;

COMMENT ON FUNCTION public.ean13_valido(text) IS
  'Verifica el dígito de control de un EAN-13. Los códigos los asigna GS1 Colombia; la app no los genera, solo los valida.';

-- ─── Guardar referencia ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.guardar_referencia(p jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE
  v_id          uuid := nullif(p->>'id','')::uuid;
  v_nombre      text := upper(btrim(coalesce(p->>'nombre','')));
  v_base        text := upper(btrim(coalesce(p->>'referencia_base','')));
  v_cat         text := btrim(coalesce(p->>'categoria',''));
  v_tipo        text := coalesce(nullif(btrim(p->>'tipo_inventario'),''), 'INV002');
  v_pvp         int  := nullif(p->>'precio_venta','')::int;
  v_kukos       int  := nullif(p->>'precio_neto_kukos','')::int;
  v_min         int  := coalesce(nullif(p->>'stock_minimo','')::int, 10);
  v_activo      bool := coalesce((p->>'activo')::bool, true);
  v_ficha       jsonb := coalesce(p->'ficha','{}'::jsonb);
  v_variantes   jsonb := coalesce(p->'variantes','[]'::jsonb);
  v_costos      jsonb := p->'costos';
  v_nombre_ant  text;
  r             jsonb;
  v_cod         text;
  v_dueno       text;
  v_tallas      text[] := '{}';
  v_guardadas   int := 0;
  v_pend        int := 0;
  v_desactivadas int := 0;
  v_avisos      jsonb := '[]'::jsonb;
BEGIN
  -- ── Validaciones de la referencia ──
  IF v_nombre = '' THEN
    RETURN jsonb_build_object('ok', false, 'campo','nombre', 'motivo','Escribe el nombre de la referencia');
  END IF;
  IF v_base !~ '^[A-Z0-9]{4,20}$' THEN
    RETURN jsonb_build_object('ok', false, 'campo','referencia_base',
      'motivo','El código de referencia solo admite letras y números (ej. ANT8062)');
  END IF;
  IF v_pvp IS NULL OR v_pvp <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'campo','precio_venta', 'motivo','Escribe el precio de venta');
  END IF;

  -- código de referencia único
  PERFORM 1 FROM productos WHERE referencia_base = v_base AND (v_id IS NULL OR id <> v_id);
  IF FOUND THEN
    RETURN jsonb_build_object('ok', false, 'campo','referencia_base',
      'motivo', 'Ya existe: ' || (SELECT nombre FROM productos WHERE referencia_base = v_base LIMIT 1));
  END IF;

  -- nombre único: el resto de la app (conteos, ventas, remisiones) identifica el producto
  -- por su NOMBRE, así que dos referencias con el mismo nombre mezclarían sus saldos.
  PERFORM 1 FROM productos WHERE upper(btrim(nombre)) = v_nombre AND (v_id IS NULL OR id <> v_id);
  IF FOUND THEN
    RETURN jsonb_build_object('ok', false, 'campo','nombre',
      'motivo', 'Ya hay una referencia con ese nombre: ' ||
        (SELECT referencia_base FROM productos WHERE upper(btrim(nombre)) = v_nombre LIMIT 1));
  END IF;

  IF v_tipo NOT IN (SELECT codigo FROM tipos_inventario) AND EXISTS (SELECT 1 FROM tipos_inventario) THEN
    RETURN jsonb_build_object('ok', false, 'campo','tipo_inventario',
      'motivo','Tipo de inventario desconocido: ' || v_tipo);
  END IF;

  -- ── Validaciones de las tallas, TODAS antes de escribir nada ──
  FOR r IN SELECT jsonb_array_elements(v_variantes) LOOP
    IF coalesce(btrim(r->>'talla'),'') = '' THEN
      RETURN jsonb_build_object('ok', false, 'campo','variantes', 'motivo','Hay una fila sin talla');
    END IF;
    IF btrim(r->>'talla') = ANY (v_tallas) THEN
      RETURN jsonb_build_object('ok', false, 'campo','variantes',
        'motivo','La talla ' || (r->>'talla') || ' está repetida');
    END IF;
    v_tallas := array_append(v_tallas, btrim(r->>'talla'));

    v_cod := nullif(btrim(coalesce(r->>'codigo_barras','')), '');
    IF v_cod IS NOT NULL THEN
      IF NOT ean13_valido(v_cod) THEN
        RETURN jsonb_build_object('ok', false, 'campo','codigo_barras', 'talla', r->>'talla',
          'motivo','El código ' || v_cod || ' no es un EAN-13 válido (dígito de control incorrecto)');
      END IF;
      IF v_cod NOT LIKE '7706730%' THEN
        RETURN jsonb_build_object('ok', false, 'campo','codigo_barras', 'talla', r->>'talla',
          'motivo','El código ' || v_cod || ' no empieza por 7706730, que es el prefijo de Antonia');
      END IF;
      SELECT pr.referencia_base || ' – talla ' || pv.talla INTO v_dueno
        FROM productos_variantes pv JOIN productos pr ON pr.id = pv.producto_id
       WHERE pv.codigo_barras = v_cod AND (v_id IS NULL OR pv.producto_id <> v_id);
      IF v_dueno IS NOT NULL THEN
        RETURN jsonb_build_object('ok', false, 'campo','codigo_barras', 'talla', r->>'talla',
          'motivo','Ya pertenece a ' || v_dueno);
      END IF;
    END IF;
  END LOOP;

  -- ── Referencia ──
  IF v_id IS NULL THEN
    INSERT INTO productos (nombre, referencia_base, categoria, tipo_inventario, precio_venta,
                           precio_neto_kukos, stock_minimo, activo, desc_larga, desc_corta,
                           k_linea, k_genero, k_componente, k_silueta, k_uso)
    VALUES (v_nombre, v_base, v_cat, v_tipo, v_pvp, v_kukos, v_min, v_activo,
            nullif(v_ficha->>'desc_larga',''), nullif(v_ficha->>'desc_corta',''),
            nullif(v_ficha->>'linea',''), nullif(v_ficha->>'genero',''),
            nullif(v_ficha->>'componente',''), nullif(v_ficha->>'silueta',''),
            nullif(v_ficha->>'uso',''))
    RETURNING id INTO v_id;
  ELSE
    SELECT nombre INTO v_nombre_ant FROM productos WHERE id = v_id;
    UPDATE productos SET nombre=v_nombre, referencia_base=v_base, categoria=v_cat,
      tipo_inventario=v_tipo, precio_venta=v_pvp, precio_neto_kukos=v_kukos,
      stock_minimo=v_min, activo=v_activo,
      desc_larga=nullif(v_ficha->>'desc_larga',''), desc_corta=nullif(v_ficha->>'desc_corta',''),
      k_linea=nullif(v_ficha->>'linea',''), k_genero=nullif(v_ficha->>'genero',''),
      k_componente=nullif(v_ficha->>'componente',''), k_silueta=nullif(v_ficha->>'silueta',''),
      k_uso=nullif(v_ficha->>'uso',''), updated_at=now()
     WHERE id = v_id;
  END IF;

  -- ── Tallas ──
  -- Las que ya no vienen en el formulario se DESACTIVAN, nunca se borran: pueden tener
  -- stock o ventas detrás, y perder ese rastro es peor que dejar una talla apagada.
  UPDATE productos_variantes SET activo = false
   WHERE producto_id = v_id AND talla <> ALL (v_tallas);
  v_desactivadas := (SELECT count(*) FROM productos_variantes
                      WHERE producto_id = v_id AND NOT activo);

  FOR r IN SELECT jsonb_array_elements(v_variantes) LOOP
    v_cod := nullif(btrim(coalesce(r->>'codigo_barras','')), '');
    INSERT INTO productos_variantes (producto_id, referencia, talla, codigo_barras,
                                     estado_codigo, activo, precio_venta)
    -- El SKU sigue el formato que ya tienen las 143 variantes (ANT8062M2600). Es único,
    -- así que se fija al crear y en adelante no se toca: reescribirlo rompería el enlace
    -- con las ventas viejas, que van por ese código.
    VALUES (v_id, v_base || btrim(r->>'talla') || '2600', btrim(r->>'talla'), v_cod,
            CASE WHEN v_cod IS NULL THEN 'pendiente_gs1' ELSE 'asignado' END,
            coalesce((r->>'activo')::bool, true), v_pvp)
    ON CONFLICT (producto_id, talla) DO UPDATE
      SET codigo_barras = EXCLUDED.codigo_barras,
          estado_codigo = EXCLUDED.estado_codigo,
          activo        = EXCLUDED.activo,
          precio_venta  = EXCLUDED.precio_venta;
    v_guardadas := v_guardadas + 1;
    IF v_cod IS NULL THEN v_pend := v_pend + 1; END IF;
  END LOOP;

  -- ── Espejo en bodega, que es por donde el resto de la app ve los productos ──
  IF v_nombre_ant IS NOT NULL AND v_nombre_ant <> v_nombre THEN
    UPDATE bodega SET referencia = v_nombre WHERE referencia = v_nombre_ant;
    v_avisos := v_avisos || jsonb_build_array(
      'El nombre cambió de "' || v_nombre_ant || '" a "' || v_nombre ||
      '". Revisa que conteos y ventas viejas sigan cuadrando.');
  END IF;
  -- `bodega` no tiene restricción única en `referencia` (solo PK por id), así que no se
  -- puede usar ON CONFLICT: se actualiza y, si no existía, se inserta.
  UPDATE bodega SET categoria = v_cat, stock_minimo = v_min WHERE referencia = v_nombre;
  IF NOT FOUND THEN
    INSERT INTO bodega (referencia, categoria, stock, costo, stock_minimo)
    VALUES (v_nombre, v_cat, 0, 0, v_min);
  END IF;

  UPDATE productos SET referencia_inventario = v_nombre WHERE id = v_id;

  -- ── Precio para Costos/Rentabilidad (va por nombre de inventario) ──
  INSERT INTO referencia_costos (referencia, precio_venta)
  VALUES (v_nombre, v_pvp)
  ON CONFLICT (referencia) DO UPDATE SET precio_venta = EXCLUDED.precio_venta, updated_at = now();

  -- ── Costos (opcional) ──
  IF v_costos IS NOT NULL AND v_costos <> 'null'::jsonb THEN
    UPDATE referencia_costos
       SET costo_produccion  = coalesce(nullif(v_costos->>'costo_produccion','')::int, costo_produccion),
           costo_comercial   = coalesce(nullif(v_costos->>'costo_comercial','')::int, costo_comercial),
           factor_produccion = coalesce(nullif(v_costos->>'factor_produccion','')::numeric, factor_produccion),
           updated_at = now()
     WHERE referencia = v_nombre;

    IF v_costos ? 'insumos' THEN
      DELETE FROM referencia_insumos WHERE referencia = v_nombre;
      INSERT INTO referencia_insumos (referencia, nombre, valor, consumo, precio_iva, orden)
      SELECT v_nombre,
             btrim(i->>'nombre'),
             coalesce(nullif(i->>'valor','')::int, 0),
             nullif(i->>'consumo','')::numeric,
             nullif(i->>'precio_iva','')::numeric,
             ord
        FROM jsonb_array_elements(v_costos->'insumos') WITH ORDINALITY AS t(i, ord)
       WHERE coalesce(btrim(i->>'nombre'),'') <> '';
    END IF;
  END IF;

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'referencia_base', v_base,
    'nombre', v_nombre, 'tallas_guardadas', v_guardadas, 'pendientes_gs1', v_pend,
    'tallas_desactivadas', v_desactivadas, 'avisos', v_avisos);
END $fn$;

GRANT EXECUTE ON FUNCTION public.ean13_valido(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.guardar_referencia(jsonb) TO anon, authenticated;

-- ─── Comprobación del dígito de control ───────────────────────────
SELECT ean13_valido('7706730455433') AS valido_real,       -- pijama capri vera talla M
       ean13_valido('7706730455434') AS invalido_un_digito,
       ean13_valido('770673045543')  AS invalido_corto,
       ean13_valido(NULL)            AS nulo;
-- Esperado: true · false · false · false
