
--------
-- View for the swmm module class subcatchments
-- 20190329 qgep code sprint SB, TP
-- 20220201 SB based on suggestion in https://github.com/QGEP/QGEP/issues/697
--------

CREATE OR REPLACE VIEW qgep_swmm.vw_subcatchments AS
SELECT
  concat(replace(ca.obj_id, ' ', '_'), '_', state) as Name,
  concat('raingage@', replace(ca.obj_id, ' ', '_'))::varchar as RainGage,
  CASE
    WHEN state = 'rw_current' then fk_wastewater_networkelement_rw_current
    WHEN state = 'rw_planned'  then fk_wastewater_networkelement_rw_planned
    WHEN state = 'ww_current' then fk_wastewater_networkelement_ww_current
    WHEN state = 'ww_planned'  then fk_wastewater_networkelement_ww_planned
    ELSE replace(ca.obj_id, ' ', '_')
  END as Outlet,
  CASE
            WHEN ca.surface_area IS NULL THEN st_area(ca.perimeter_geometry)/10000
            WHEN ca.surface_area < 0.01 THEN st_area(ca.perimeter_geometry)/10000
            ELSE (ca.surface_area::numeric)::double precision
  END AS Area,
  CASE
    WHEN state = 'rw_current' then discharge_coefficient_rw_current
    WHEN state = 'rw_planned'  then discharge_coefficient_rw_planned
    WHEN state = 'ww_current' then discharge_coefficient_ww_current
    WHEN state = 'ww_planned'  then discharge_coefficient_ww_planned
    ELSE 0
  END as percImperv, -- take from catchment_area instead of default value
  CASE
    WHEN wn_geom IS NOT NULL
    THEN 	
    (
    st_maxdistance(wn_geom, ST_ExteriorRing(perimeter_geometry))
    + st_distance(wn_geom, ST_ExteriorRing(perimeter_geometry))
    )/2
    ELSE
    (
    st_maxdistance(st_centroid(perimeter_geometry), ST_ExteriorRing(perimeter_geometry))
    + st_distance(st_centroid(perimeter_geometry), ST_ExteriorRing(perimeter_geometry))
    )/2
  END as Width, -- Width of overland flow path estimation
  0.5 as percSlope, -- default value
  0 as CurbLen, -- default value
  NULL::varchar as SnowPack, -- default value
  CONCAT(ca.identifier, ', ', regexp_replace(ca.remark,'[\n\r]+', ', ', 'g' )) as description,
  ca.obj_id as tag,
  ST_CurveToLine(perimeter_geometry)::geometry(Polygon, %(SRID)s) as geom,
  CASE
    WHEN state = 'rw_current' OR state = 'ww_current' THEN 'current'
    WHEN state = 'rw_planned' OR state = 'ww_planned' THEN 'planned'
    ELSE 'planned'
  END as state
FROM (
  SELECT ca.*, wn.situation_geometry as wn_geom, 'rw_current' as state FROM qgep_od.catchment_area as ca
  INNER JOIN qgep_od.wastewater_networkelement we on we.obj_id = ca.fk_wastewater_networkelement_rw_current
  LEFT JOIN qgep_od.wastewater_node wn on wn.obj_id = we.obj_id
  UNION ALL
  SELECT ca.*, wn.situation_geometry as wn_geom, 'rw_planned' as state FROM qgep_od.catchment_area as ca
  INNER JOIN qgep_od.wastewater_networkelement we on we.obj_id = ca.fk_wastewater_networkelement_rw_planned
  LEFT JOIN qgep_od.wastewater_node wn on wn.obj_id = we.obj_id
  UNION ALL
  SELECT ca.*, wn.situation_geometry as wn_geom, 'ww_current' as state FROM qgep_od.catchment_area as ca
  INNER JOIN qgep_od.wastewater_networkelement we on we.obj_id = ca.fk_wastewater_networkelement_ww_current
  LEFT JOIN qgep_od.wastewater_node wn on wn.obj_id = we.obj_id
  UNION ALL
  SELECT ca.*, wn.situation_geometry as wn_geom,'ww_planned' as state FROM qgep_od.catchment_area as ca
  INNER JOIN qgep_od.wastewater_networkelement we on we.obj_id = ca.fk_wastewater_networkelement_ww_planned
  LEFT JOIN qgep_od.wastewater_node wn on wn.obj_id = we.obj_id
) as ca;


-- Creates subarea related to the subcatchment
CREATE OR REPLACE VIEW qgep_swmm.vw_subareas AS
SELECT concat(replace(ca.obj_id::text, ' '::text, '_'::text), '_', ca.state) AS subcatchment,
  0.01 as NImperv, -- default value, Manning's n for overland flow over the impervious portion of the subcatchment 
  0.1 as NPerv,-- default value, Manning's n for overland flow over the pervious portion of the subcatchment
  CASE
	  WHEN surface_storage IS NOT NULL THEN surface_storage	
	  ELSE 0.05 -- default value
  END as SImperv,-- Depth of depression storage on the impervious portion of the subcatchment (inches or millimeters)
  CASE
  	WHEN surface_storage IS NOT NULL THEN surface_storage	
  	ELSE 0.05 -- default value
  END as SPerv,-- Depth of depression storage on the pervious portion of the subcatchment (inches or millimeters)
  25 as PctZero,-- default value, Percent of the impervious area with no depression storage.
  'OUTLET'::varchar as RouteTo,
  NULL::float as PctRouted,
	CONCAT(ca.identifier, ', ', regexp_replace(ca.remark,'[\n\r]+', ', ', 'g' )) AS description,
	ca.obj_id AS tag,
	CASE
		WHEN ca.state = 'rw_current'::text OR ca.state = 'ww_current'::text THEN 'current'::text
		WHEN ca.state = 'rw_planned'::text OR ca.state = 'ww_planned'::text THEN 'planned'::text
		ELSE 'planned'::text
	END AS state
FROM 
(
SELECT ca.*, sr.surface_storage, 'rw_current' as state
FROM qgep_od.catchment_area as ca
LEFT JOIN qgep_od.surface_runoff_parameters sr ON ca.obj_id = sr.fk_catchment_area
WHERE fk_wastewater_networkelement_rw_current IS NOT NULL -- to avoid unconnected catchments
UNION ALL
SELECT ca.*, sr.surface_storage, 'ww_current' as state
FROM qgep_od.catchment_area as ca
LEFT JOIN qgep_od.surface_runoff_parameters sr ON ca.obj_id = sr.fk_catchment_area
WHERE fk_wastewater_networkelement_ww_current IS NOT NULL -- to avoid unconnected catchments
UNION ALL
SELECT ca.*, sr.surface_storage, 'rw_planned' as state
FROM qgep_od.catchment_area as ca
LEFT JOIN qgep_od.surface_runoff_parameters sr ON ca.obj_id = sr.fk_catchment_area
WHERE fk_wastewater_networkelement_rw_planned IS NOT NULL -- to avoid unconnected catchments
UNION ALL
SELECT ca.*, sr.surface_storage, 'ww_planned' as state
FROM qgep_od.catchment_area as ca
LEFT JOIN qgep_od.surface_runoff_parameters sr ON ca.obj_id = sr.fk_catchment_area
WHERE fk_wastewater_networkelement_ww_planned IS NOT NULL -- to avoid unconnected catchments
) as ca;

-- Creates Dry Weather Flow related to the catchment area
CREATE OR REPLACE VIEW qgep_swmm.vw_dwf AS
SELECT
  CASE 
    WHEN state = 'current' THEN fk_wastewater_networkelement_rw_current
    WHEN state = 'planned' THEN fk_wastewater_networkelement_rw_planned
  END as Node, -- id of the junction
  'FLOW'::varchar as Constituent,
	CASE
		WHEN ca.surface_area IS NOT NULL THEN
		CASE
			WHEN ca.state = 'current'::text AND ca.population_density_current IS NOT NULL THEN ca.population_density_current::numeric * ca.surface_area * 160::numeric / (24 * 60 * 60)::numeric
			WHEN ca.state = 'planned'::text AND ca.population_density_planned IS NOT NULL THEN ca.population_density_planned::numeric * ca.surface_area * 160::numeric / (24 * 60 * 60)::numeric
			ELSE 0::numeric
		END::double precision
		ELSE
		CASE
			WHEN ca.state = 'current'::text AND ca.population_density_current IS NOT NULL THEN ca.population_density_current::double precision * st_area(ca.perimeter_geometry) * 160::double precision / (24 * 60 * 60)::double precision
			WHEN ca.state = 'planned'::text AND ca.population_density_planned IS NOT NULL THEN ca.population_density_planned::double precision * st_area(ca.perimeter_geometry) * 160::double precision / (24 * 60 * 60)::double precision
			ELSE 0::double precision
		END
	END AS baseline, -- 160 Litre / inhabitant /day
  'dailyPatternDWF'::varchar as Patterns,
  state as state
FROM 
(
SELECT ca.*,'current' as state
FROM qgep_od.catchment_area as ca
WHERE fk_wastewater_networkelement_rw_current IS NOT NULL -- to avoid unconnected catchments
UNION ALL
SELECT ca.*,'planned' as state
FROM qgep_od.catchment_area as ca
WHERE fk_wastewater_networkelement_rw_planned IS NOT NULL -- to avoid unconnected catchments
) as ca;

-- Creates a default raingage for each subcatchment
CREATE OR REPLACE VIEW qgep_swmm.vw_raingages AS
SELECT
  ('raingage@' || replace(ca.obj_id, ' ', '_'))::varchar as Name,
  'INTENSITY'::varchar as Format,
  '0:15'::varchar as Interval,
  '1.0'::varchar as SCF,
  'TIMESERIES default_qgep_raingage_timeserie'::varchar as Source,
  st_centroid(perimeter_geometry)::geometry(Point, %(SRID)s) as geom,
  state
FROM 
(
SELECT ca.*,'current' as state
FROM qgep_od.catchment_area as ca
WHERE fk_wastewater_networkelement_rw_current IS NOT NULL -- to avoid unconnected catchments
UNION
SELECT ca.*,'planned' as state
FROM qgep_od.catchment_area as ca
WHERE fk_wastewater_networkelement_rw_planned IS NOT NULL -- to avoid unconnected catchments
UNION
SELECT ca.*,'current' as state
FROM qgep_od.catchment_area as ca
WHERE fk_wastewater_networkelement_ww_current IS NOT NULL -- to avoid unconnected catchments
UNION
SELECT ca.*,'planned' as state
FROM qgep_od.catchment_area as ca
WHERE fk_wastewater_networkelement_ww_planned IS NOT NULL -- to avoid unconnected catchments
) as ca;

-- Creates default infiltration for each subcatchment
CREATE OR REPLACE VIEW qgep_swmm.vw_infiltration AS
SELECT
  CASE 
    WHEN state = 'current' THEN concat(replace(ca.obj_id, ' ', '_'), '_', 'rw_current')
    WHEN state = 'planned' THEN concat(replace(ca.obj_id, ' ', '_'), '_', 'rw_planned')
  END as Subcatchment,
  3 as MaxRate,
  0.5 as MinRate,
  4 as Decay,
  7 as DryTime,
  0 as MaxInfil,
  state
FROM 
(
SELECT ca.*,'current' as state
FROM qgep_od.catchment_area as ca
WHERE fk_wastewater_networkelement_rw_current IS NOT NULL -- to avoid unconnected catchments
UNION ALL
SELECT ca.*,'planned' as state
FROM qgep_od.catchment_area as ca
WHERE fk_wastewater_networkelement_rw_planned IS NOT NULL -- to avoid unconnected catchments
) as ca;


-- creates coverages
CREATE OR REPLACE VIEW qgep_swmm.vw_coverages AS
SELECT
  replace(ca.obj_id, ' ', '_')  as Subcatchment,
  pzk.value_en as landUse,
  round((st_area(st_intersection(ca.perimeter_geometry, pz.perimeter_geometry))/st_area(ca.perimeter_geometry))::numeric,2)*100 as percent
FROM qgep_od.catchment_area ca, qgep_od.planning_zone pz
LEFT JOIN qgep_vl.planning_zone_kind pzk on pz.kind = pzk.code
WHERE st_intersects(ca.perimeter_geometry, pz.perimeter_geometry)
AND st_isvalid(ca.perimeter_geometry) AND st_isvalid(pz.perimeter_geometry)
ORDER BY ca.obj_id, percent DESC;
