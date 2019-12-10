--------
-- View for the swmm module class dividers
-- 20190329 qgep code sprint SB, TP
-- Question attribute Diverted Link: Name of link which receives the diverted flow. overflow > fk_overflow_to

DROP VIEW IF EXISTS qgep_swmm.vw_dividers;

CREATE OR REPLACE VIEW qgep_swmm.vw_dividers AS

SELECT
	ma.obj_id as Name,
	st_x(wn.situation_geometry) as X_coordinate,
	st_y(wn.situation_geometry) as Y_coordinate,
	ws.identifier as description,
	'manhole' as tag,
	wn.bottom_level as invert_elev,
	(co.level-wn.bottom_level) as max_depth,
	'???' as diverted_link
FROM qgep_od.manhole ma
LEFT JOIN qgep_od.wastewater_structure ws ON ws.obj_id::text = ma.obj_id::text
LEFT JOIN qgep_od.wastewater_networkelement we ON we.fk_wastewater_structure::text = ws.obj_id::text
LEFT JOIN qgep_od.wastewater_node wn on wn.obj_id = we.obj_id
LEFT JOIN qgep_od.cover co on ws.fk_main_cover = co.obj_id
WHERE function = 4798 -- separating_structure
AND ws._function_hierarchic in (5066, 5068, 5069, 5070, 5064, 5071, 5062, 5072, 5074)

UNION ALL

SELECT
	ss.obj_id as Name,
	st_x(wn.situation_geometry) as X_coordinate,
	st_y(wn.situation_geometry) as Y_coordinate,
	ws.identifier as description,
	'special_stucture' as tag,
	wn.bottom_level as invert_elev,
	(co.level-wn.bottom_level) as max_depth,
	'???' as diverted_link
FROM qgep_od.special_structure ss
LEFT JOIN qgep_od.wastewater_structure ws ON ws.obj_id::text = ss.obj_id::text
LEFT JOIN qgep_od.wastewater_networkelement we ON we.fk_wastewater_structure::text = ws.obj_id::text
LEFT JOIN qgep_od.wastewater_node wn on wn.obj_id = we.obj_id
LEFT JOIN qgep_od.cover co on ws.fk_main_cover = co.obj_id
WHERE function  = 4799 -- separating_structure
AND ws._function_hierarchic in (5066, 5068, 5069, 5070, 5064, 5071, 5062, 5072, 5074);
