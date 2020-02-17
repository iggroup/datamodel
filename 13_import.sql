-- create quarantine table

DROP TABLE IF EXISTS qgep_import.manhole_quarantine CASCADE;

CREATE TABLE qgep_import.manhole_quarantine
(
  obj_id character varying(16),
  identifier character varying(20),
  situation_geometry geometry(POINTZ, :SRID),
  co_shape integer,
  co_diameter smallint,
  co_material integer,
  co_positional_accuracy integer,
  co_level numeric(7,3),
  _depth numeric(6,3),
  _channel_usage_current integer,
  ma_material integer,
  ma_dimension1 smallint,
  ma_dimension2 smallint,
  ws_type text,
  ma_function integer,
  ss_function integer,
  remark character varying(80),
  wn_bottom_level numeric(7,3),
  photo1 text,
  photo2 text,
  inlet_3_material smallint,
  inlet_3_clear_height integer,
  inlet_3_depth_m numeric(7,3),
  inlet_4_material smallint,
  inlet_4_clear_height integer,
  inlet_4_depth_m numeric(7,3),
  inlet_5_material smallint,
  inlet_5_clear_height integer,
  inlet_5_depth_m numeric(7,3),
  inlet_6_material smallint,
  inlet_6_clear_height integer,
  inlet_6_depth_m numeric(7,3),
  inlet_7_material smallint,
  inlet_7_clear_height integer,
  inlet_7_depth_m numeric(7,3),
  outlet_1_material smallint,
  outlet_1_clear_height integer,
  outlet_1_depth_m numeric(7,3),
  outlet_2_material smallint,
  outlet_2_clear_height integer,
  outlet_2_depth_m numeric(7,3),
  structure_okay boolean DEFAULT false,
  inlet_okay boolean DEFAULT false,
  outlet_okay boolean DEFAULT false,
  deleted boolean DEFAULT false,
  quarantine_serial SERIAL PRIMARY KEY
);

-- create trigger functions and triggers for quarantine table
SELECT set_config('qgep.srid', :SRID::text, false);
DO $DO$
BEGIN
EXECUTE format($TRIGGER$
CREATE OR REPLACE FUNCTION qgep_import.manhole_quarantine_try_structure_update() RETURNS trigger AS $BODY$
BEGIN

  -- in case there is a depth, but no refercing value - it should stay in quarantene
  IF( NEW._depth IS NOT NULL AND NEW.co_level IS NULL AND NEW.wn_bottom_level IS NULL ) THEN
    RAISE EXCEPTION 'No referencing value for calculation with depth';
  END IF;

  -- qgep_od.wastewater_structure
  IF( SELECT TRUE FROM qgep_od.vw_qgep_wastewater_structure WHERE obj_id = NEW.obj_id ) THEN
    UPDATE qgep_od.vw_qgep_wastewater_structure SET
    identifier = NEW.identifier,
    situation_geometry = ST_Force2D(NEW.situation_geometry),
    co_shape = NEW.co_shape,
    co_diameter = NEW.co_diameter,
    co_material = NEW.co_material,
    co_positional_accuracy = NEW.co_positional_accuracy,
    co_level =
      (CASE WHEN NEW.co_level IS NULL AND NEW.wn_bottom_level IS NOT NULL AND NEW._depth IS NOT NULL
      THEN NEW.wn_bottom_level + NEW._depth
      ELSE NEW.co_level
      END),
    _depth = NEW._depth,
    _channel_usage_current = NEW._channel_usage_current,
    ma_material = NEW.ma_material,
    ma_dimension1 = NEW.ma_dimension1,
    ma_dimension2 = NEW.ma_dimension2,
    ws_type = NEW.ws_type,
    ma_function = NEW.ma_function,
    ss_function = NEW.ss_function,
    remark = NEW.remark,
    wn_bottom_level =
      (CASE WHEN NEW.wn_bottom_level IS NULL AND NEW.co_level IS NOT NULL AND NEW._depth IS NOT NULL
      THEN NEW.co_level - NEW._depth
      ELSE NEW.wn_bottom_level
      END)
    WHERE obj_id = NEW.obj_id;
    RAISE NOTICE 'Updated row in qgep_od.vw_qgep_wastewater_structure';
  ELSE
    INSERT INTO qgep_od.vw_qgep_wastewater_structure
    (
    obj_id,
    identifier,
    situation_geometry,
    co_shape,
    co_diameter,
    co_material,
    co_positional_accuracy,
    co_level,
    _depth,
    _channel_usage_current,
    ma_material,
    ma_dimension1,
    ma_dimension2,
    ws_type,
    ma_function,
    ss_function,
    remark,
    wn_bottom_level
    )
    VALUES
    (
    NEW.obj_id,
    NEW.identifier,
    ST_Force2D(NEW.situation_geometry),
    NEW.co_shape,
    NEW.co_diameter,
    NEW.co_material,
    NEW.co_positional_accuracy,
      (CASE WHEN NEW.co_level IS NULL AND NEW.wn_bottom_level IS NOT NULL AND NEW._depth IS NOT NULL
      THEN NEW.wn_bottom_level + NEW._depth
      ELSE NEW.co_level
      END),
    NEW._depth,
    NEW._channel_usage_current,
    NEW.ma_material,
    NEW.ma_dimension1,
    NEW.ma_dimension2,
    NEW.ws_type,
    NEW.ma_function,
    NEW.ss_function,
    NEW.remark,
      (CASE WHEN NEW.wn_bottom_level IS NULL AND NEW.co_level IS NOT NULL AND NEW._depth IS NOT NULL
      THEN NEW.co_level - NEW._depth
      ELSE NEW.wn_bottom_level
      END)
      );
    RAISE NOTICE 'Inserted row in qgep_od.vw_qgep_wastewater_structure';
  END IF;

  -- photo1 insert
  IF (NEW.photo1 IS NOT NULL) THEN
    INSERT INTO qgep_od.file
    (
      object,
      identifier
    )
    VALUES
    (
      NEW.obj_id,
      NEW.photo1
    );
    RAISE NOTICE 'Inserted row in qgep_od.file';
  END IF;

  -- photo2 insert
  IF (NEW.photo2 IS NOT NULL) THEN
    INSERT INTO qgep_od.file
    (
      object,
      identifier
    )
    VALUES
    (
      NEW.obj_id,
      NEW.photo2
    );
    RAISE NOTICE 'Inserted row in qgep_od.file';
  END IF;

  -- set structure okay
  UPDATE qgep_import.manhole_quarantine
  SET structure_okay = true
  WHERE quarantine_serial = NEW.quarantine_serial;
  RETURN NEW;

  -- catch
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'EXCEPTION: %%', SQLERRM;
    RETURN NEW;
END; $BODY$
LANGUAGE plpgsql;
$TRIGGER$, current_setting('qgep.srid'));
END
$DO$;

DROP TRIGGER IF EXISTS after_update_try_structure_update ON qgep_import.manhole_quarantine;

CREATE TRIGGER after_update_try_structure_update
  AFTER UPDATE
  ON qgep_import.manhole_quarantine
  FOR EACH ROW
  WHEN ( ( NEW.structure_okay IS NOT TRUE )
  AND NOT( OLD.inlet_okay IS NOT TRUE AND NEW.inlet_okay IS TRUE )
  AND NOT( OLD.outlet_okay IS NOT TRUE AND NEW.outlet_okay IS TRUE ) )
  EXECUTE PROCEDURE qgep_import.manhole_quarantine_try_structure_update(:SRID);

DROP TRIGGER IF EXISTS after_insert_try_structure_update ON qgep_import.manhole_quarantine;

CREATE TRIGGER after_insert_try_structure_update
  AFTER INSERT
  ON qgep_import.manhole_quarantine
  FOR EACH ROW
  EXECUTE PROCEDURE qgep_import.manhole_quarantine_try_structure_update(:SRID);

-- Some information:
-- 1. new lets 0 - old lets 0 -> do nothing
-- 2. new lets 0 - old lets 1 -> manual deletion needed (or not, depending on if it's on purpose or not)
-- 3. new lets 0 - old lets n -> manual deletion needed (or not, depending on if it's on purpose or not)
-- 4. new lets 1 - old lets 0 -> manual creation needed
-- 5. new lets 1 - old lets 1 -> update let
-- 6. new lets 1 - old lets n -> manual update needed
-- 7. new lets n - old lets 0 -> manual creation needed
-- 8. new lets n - old lets 1 -> manual update needed
-- 9. new lets n - old lets n -> manual update needed

CREATE OR REPLACE FUNCTION qgep_import.manhole_quarantine_try_let_update() RETURNS trigger AS $BODY$
  DECLARE
    let_kind text;
    new_lets integer;
    old_lets integer;
BEGIN
  let_kind := TG_ARGV[0];

  -- count new lets
  IF let_kind='inlet' AND ( NEW.inlet_3_material IS NOT NULL OR NEW.inlet_3_depth_m IS NOT NULL OR NEW.inlet_3_clear_height IS NOT NULL )
   OR let_kind='outlet' AND ( NEW.outlet_1_material IS NOT NULL OR NEW.outlet_1_depth_m IS NOT NULL OR NEW.outlet_1_clear_height IS NOT NULL ) THEN
    IF let_kind='inlet' AND ( NEW.inlet_4_material IS NOT NULL OR NEW.inlet_4_depth_m IS NOT NULL OR NEW.inlet_4_clear_height IS NOT NULL )
     OR let_kind='outlet' AND ( NEW.outlet_2_material IS NOT NULL OR NEW.outlet_2_depth_m IS NOT NULL OR NEW.outlet_2_clear_height IS NOT NULL ) THEN
      new_lets = 2; -- it's possibly more, but at least > 1
    ELSE
      new_lets = 1;
    END IF;
  ELSE
    new_lets = 0;
  END IF;
  -- count old lets
  old_lets = ( SELECT COUNT (*)
    FROM qgep_od.reach re
    LEFT JOIN qgep_od.reach_point rp ON let_kind='inlet' AND rp.obj_id = re.fk_reach_point_to OR let_kind='outlet' AND rp.obj_id = re.fk_reach_point_from
    LEFT JOIN qgep_od.wastewater_networkelement wn ON wn.obj_id = rp.fk_wastewater_networkelement
    LEFT JOIN qgep_od.vw_qgep_wastewater_structure ws ON ws.obj_id = wn.fk_wastewater_structure
    WHERE ws.obj_id = NEW.obj_id );

  -- handle inlets
  IF ( new_lets > 1 AND old_lets > 0 ) OR old_lets > 1 THEN
    -- request for update because new lets are bigger 1 (and old lets not 0 ) or old lets are bigger 1
    RAISE NOTICE 'Impossible to assign %s - manual edit needed.', let_kind;
  ELSE
    IF new_lets = 0 AND old_lets > 0 THEN
      -- request for delete because no new lets but old lets
      RAISE NOTICE 'No new %s but old ones - manual delete needed.', let_kind;
    ELSIF new_lets > 0 AND old_lets = 0 THEN
      -- request for create because no old lets but new lets
      RAISE NOTICE 'No old %s but new ones - manual create needed.', let_kind;
    ELSE
      IF new_lets = 1 AND old_lets = 1 THEN
        IF let_kind='inlet' THEN
          -- update material and dimension on reach
          UPDATE qgep_od.reach
          SET material = NEW.inlet_3_material,
          clear_height = NEW.inlet_3_clear_height
          WHERE obj_id = ( SELECT re.obj_id
            FROM qgep_od.reach re
            LEFT JOIN qgep_od.reach_point rp ON rp.obj_id = re.fk_reach_point_to
            LEFT JOIN qgep_od.wastewater_networkelement wn ON wn.obj_id = rp.fk_wastewater_networkelement
            LEFT JOIN qgep_od.vw_qgep_wastewater_structure ws ON ws.obj_id = wn.fk_wastewater_structure
            WHERE ws.obj_id = NEW.obj_id );

          -- update depth_m on reach_point
          UPDATE qgep_od.reach_point
          SET level = NEW.co_level - NEW.inlet_3_depth_m
          WHERE obj_id = ( SELECT rp.obj_id
            FROM qgep_od.reach re
            LEFT JOIN qgep_od.reach_point rp ON rp.obj_id = re.fk_reach_point_to
            LEFT JOIN qgep_od.wastewater_networkelement wn ON wn.obj_id = rp.fk_wastewater_networkelement
            LEFT JOIN qgep_od.vw_qgep_wastewater_structure ws ON ws.obj_id = wn.fk_wastewater_structure
            WHERE ws.obj_id = NEW.obj_id );
        ELSE
          -- update material on reach
          UPDATE qgep_od.reach
          SET material = NEW.outlet_1_material,
          clear_height = NEW.outlet_1_clear_height
          WHERE obj_id = ( SELECT re.obj_id
            FROM qgep_od.reach re
            LEFT JOIN qgep_od.reach_point rp ON rp.obj_id = re.fk_reach_point_from
            LEFT JOIN qgep_od.wastewater_networkelement wn ON wn.obj_id = rp.fk_wastewater_networkelement
            LEFT JOIN qgep_od.vw_qgep_wastewater_structure ws ON ws.obj_id = wn.fk_wastewater_structure
            WHERE ws.obj_id = NEW.obj_id );

          -- update depth_m on reach_point
          UPDATE qgep_od.reach_point
          SET level = NEW.co_level - NEW.outlet_1_depth_m
          WHERE obj_id = ( SELECT rp.obj_id
            FROM qgep_od.reach re
            LEFT JOIN qgep_od.reach_point rp ON rp.obj_id = re.fk_reach_point_from
            LEFT JOIN qgep_od.wastewater_networkelement wn ON wn.obj_id = rp.fk_wastewater_networkelement
            LEFT JOIN qgep_od.vw_qgep_wastewater_structure ws ON ws.obj_id = wn.fk_wastewater_structure
            WHERE ws.obj_id = NEW.obj_id );
        END IF;

        RAISE NOTICE '%s updated', let_kind;
      ELSE
        -- do nothing
        RAISE NOTICE 'No %s - nothing to do', let_kind;
      END IF;

      IF let_kind='inlet' THEN
        -- set inlet okay
        UPDATE qgep_import.manhole_quarantine
        SET inlet_okay = true
        WHERE quarantine_serial = NEW.quarantine_serial;
      ELSE
        -- set outlet okay
        UPDATE qgep_import.manhole_quarantine
        SET outlet_okay = true
        WHERE quarantine_serial = NEW.quarantine_serial;
      END IF;

    END IF;
  END IF;
  RETURN NEW;

  -- catch
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'EXCEPTION: %', SQLERRM;
    RETURN NEW;
END; $BODY$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS after_update_try_inlet_update ON qgep_import.manhole_quarantine;

CREATE TRIGGER after_update_try_inlet_update
  AFTER UPDATE
  ON qgep_import.manhole_quarantine
  FOR EACH ROW
  WHEN ( ( NEW.inlet_okay IS NOT TRUE )
  AND NOT( OLD.outlet_okay IS NOT TRUE AND NEW.outlet_okay IS TRUE )
  AND NOT( OLD.structure_okay IS NOT TRUE AND NEW.structure_okay IS TRUE ) )
  EXECUTE PROCEDURE qgep_import.manhole_quarantine_try_let_update( 'inlet' );

DROP TRIGGER IF EXISTS after_insert_try_inlet_update ON qgep_import.manhole_quarantine;

CREATE TRIGGER after_insert_try_inlet_update
  AFTER INSERT
  ON qgep_import.manhole_quarantine
  FOR EACH ROW
  EXECUTE PROCEDURE qgep_import.manhole_quarantine_try_let_update( 'inlet' );

DROP TRIGGER IF EXISTS after_update_try_outlet_update ON qgep_import.manhole_quarantine;

CREATE TRIGGER after_update_try_outlet_update
  AFTER UPDATE
  ON qgep_import.manhole_quarantine
  FOR EACH ROW
  WHEN ( ( NEW.outlet_okay IS NOT TRUE )
  AND NOT( OLD.inlet_okay IS NOT TRUE AND NEW.inlet_okay IS TRUE )
  AND NOT( OLD.structure_okay IS NOT TRUE AND NEW.structure_okay IS TRUE ) )
  EXECUTE PROCEDURE qgep_import.manhole_quarantine_try_let_update( 'outlet' );

DROP TRIGGER IF EXISTS after_insert_try_outlet_update ON qgep_import.manhole_quarantine;

CREATE TRIGGER after_insert_try_outlet_update
  AFTER INSERT
  ON qgep_import.manhole_quarantine
  FOR EACH ROW
  EXECUTE PROCEDURE qgep_import.manhole_quarantine_try_let_update( 'outlet' );


CREATE OR REPLACE FUNCTION qgep_import.manhole_quarantine_delete_entry() RETURNS trigger AS $BODY$
BEGIN
  DELETE FROM qgep_import.manhole_quarantine
  WHERE quarantine_serial = NEW.quarantine_serial;
  RAISE NOTICE 'Deleted row in qgep_import.manhole_quarantine';
  RETURN NEW;
END; $BODY$
LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS after_mutation_delete_when_okay ON qgep_import.manhole_quarantine;

CREATE TRIGGER after_mutation_delete_when_okay
  AFTER INSERT OR UPDATE
  ON qgep_import.manhole_quarantine
  FOR EACH ROW
  WHEN ( NEW.structure_okay IS TRUE AND NEW.inlet_okay IS TRUE AND NEW.outlet_okay IS TRUE )
  EXECUTE PROCEDURE qgep_import.manhole_quarantine_delete_entry();

