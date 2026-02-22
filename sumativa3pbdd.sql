CREATE DATABASE sumativa3
USE sumativa3

-- Crear secuencia simulada con AUTO_INCREMENT
CREATE TABLE CONSUMO (
    ID_CONSUMO INT PRIMARY KEY AUTO_INCREMENT,
    ID_RESERVA INT NOT NULL,
    ID_HUESPED INT NOT NULL,
    MONTO INT NOT NULL
);

CREATE TABLE TOTAL_CONSUMOS (
    ID_HUESPED INT PRIMARY KEY,
    MONTO_CONSUMOS INT NOT NULL
);

CREATE TABLE REG_ERRORES (
    ID_ERROR INT PRIMARY KEY AUTO_INCREMENT,
    NOMBRE_SUBPROGRAMA VARCHAR(100),
    MENSAJE_ERROR TEXT
);

CREATE TABLE DETALLE_DIARIO_HUESPEDES (
    ID_REGISTRO INT PRIMARY KEY AUTO_INCREMENT,
    ID_HUESPED INT,
    NOMBRE VARCHAR(100),
    AGENCIA VARCHAR(100),
    ALOJAMIENTO INT,
    TOURS INT,
    SUBTOTAL_PAGO INT,
    DESCUENTO_TOURS INT,
    DESCUENTO_AGENCIA INT,
    TOTAL INT,
    FECHA_PROCESO DATE
);

-- Insertar datos de ejemplo proporcionados
INSERT INTO CONSUMO (ID_CONSUMO, ID_RESERVA, ID_HUESPED, MONTO) VALUES
(11114, 1198, 340003, 112),
(11172, 1198, 340003, 100),
(10728, 1583, 340004, 52),
(11473, 1583, 340004, 63),
(10148, 1583, 340004, 43),
(10316, 1851, 340006, 35),
(10313, 1370, 340006, 53),
(10200, 1849, 340006, 27),
(10582, 1058, 340006, 74),
(11116, 1058, 340006, 89),
(10463, 873, 340008, 94),
(10688, 873, 340008, 117),
(11305, 1113, 340009, 83),
(10565, 1113, 340009, 59);

-- Calcular e insertar TOTAL_CONSUMOS inicial
INSERT INTO TOTAL_CONSUMOS (ID_HUESPED, MONTO_CONSUMOS)
SELECT ID_HUESPED, SUM(MONTO)
FROM CONSUMO
GROUP BY ID_HUESPED;


DELIMITER $$

CREATE TRIGGER trg_actualizar_total_consumos
AFTER INSERT ON CONSUMO
FOR EACH ROW
BEGIN
    INSERT INTO TOTAL_CONSUMOS (ID_HUESPED, MONTO_CONSUMOS) 
    VALUES (NEW.ID_HUESPED, NEW.MONTO)
    ON DUPLICATE KEY UPDATE 
    MONTO_CONSUMOS = MONTO_CONSUMOS + NEW.MONTO;
END$$

CREATE TRIGGER trg_actualizar_total_consumos_update
AFTER UPDATE ON CONSUMO
FOR EACH ROW
BEGIN
    UPDATE TOTAL_CONSUMOS 
    SET MONTO_CONSUMOS = MONTO_CONSUMOS - OLD.MONTO + NEW.MONTO
    WHERE ID_HUESPED = NEW.ID_HUESPED;
END$$

CREATE TRIGGER trg_actualizar_total_consumos_delete
AFTER DELETE ON CONSUMO
FOR EACH ROW
BEGIN
    UPDATE TOTAL_CONSUMOS 
    SET MONTO_CONSUMOS = MONTO_CONSUMOS - OLD.MONTO
    WHERE ID_HUESPED = OLD.ID_HUESPED;
END$$

DELIMITER ;


-- Bloque anónimo de prueba para el Caso 1
-- Mostrar valores antes de las operaciones
SELECT 'VALORES INICIALES' AS 'MOMENTO';
SELECT * FROM CONSUMO WHERE ID_HUESPED IN (340004, 340006, 340008);
SELECT * FROM TOTAL_CONSUMOS WHERE ID_HUESPED IN (340004, 340006, 340008);

-- 1. Insertar nuevo consumo para cliente 340006, reserva 1587, monto US$ 150
INSERT INTO CONSUMO (ID_CONSUMO, ID_RESERVA, ID_HUESPED, MONTO) 
VALUES (11527, 1587, 340006, 150);

-- 2. Eliminar consumo con ID 11473
DELETE FROM CONSUMO WHERE ID_CONSUMO = 11473;

-- 3. Actualizar a US$ 95 el consumo con ID 10688
UPDATE CONSUMO SET MONTO = 95 WHERE ID_CONSUMO = 10688;

-- Mostrar valores después de las operaciones
SELECT 'VALORES FINALES' AS 'MOMENTO';
SELECT * FROM CONSUMO WHERE ID_HUESPED IN (340004, 340006, 340008);
SELECT * FROM TOTAL_CONSUMOS WHERE ID_HUESPED IN (340004, 340006, 340008);



-- Caso 2: Package

DELIMITER $$

-- Variable de sesión para simular la variable del package
SET @monto_tours = 0;

-- Función para determinar monto de tours
CREATE FUNCTION fn_calcular_tours(p_id_huesped INT) 
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE v_total_tours INT DEFAULT 0;
    
    -- Asumiendo que los tours están en la tabla CONSUMO (tipo de consumo específico)
    -- Si no hay registros, devuelve 0
    SELECT COALESCE(SUM(MONTO), 0) INTO v_total_tours
    FROM CONSUMO
    WHERE ID_HUESPED = p_id_huesped;
    -- En un caso real, aquí filtrarías por tipo de consumo = 'TOUR'
    
    SET @monto_tours = v_total_tours;
    RETURN v_total_tours;
END$$

DELIMITER ;


-- 2. Funciones Almacenadas

DELIMITER $$

-- Función para obtener la agencia del huésped
CREATE FUNCTION fn_obtener_agencia(p_id_huesped INT) 
RETURNS VARCHAR(100)
DETERMINISTIC
BEGIN
    DECLARE v_agencia VARCHAR(100);
    DECLARE v_error_msg TEXT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
        INSERT INTO REG_ERRORES (NOMBRE_SUBPROGRAMA, MENSAJE_ERROR)
        VALUES ('FN_OBTENER_AGENCIA', CONCAT('Error para huésped ', p_id_huesped, ': ', v_error_msg));
        RETURN 'NO REGISTRA AGENCIA';
    END;
    
    -- Simulamos una consulta a una tabla de huéspedes
    SELECT CASE 
        WHEN p_id_huesped = 340008 THEN 'VIAJES PACIFICO'
        WHEN p_id_huesped = 340015 THEN 'VIAJES PACIFICO'
        WHEN p_id_huesped = 340037 THEN 'VIAJES ENIGMA'
        WHEN p_id_huesped = 340049 THEN 'VIAJES ALBERTI'
        WHEN p_id_huesped = 340096 THEN 'TRAVEL SENTRY'
        WHEN p_id_huesped = 340121 THEN 'VIAJES EL SOL'
        WHEN p_id_huesped = 340133 THEN 'VIAJES ALBERTI'
        WHEN p_id_huesped = 340138 THEN 'VIAJES ALBERTI'
        WHEN p_id_huesped = 340150 THEN 'TRAVEL SENTRY'
        WHEN p_id_huesped = 340157 THEN 'VIAJES ENIGMA'
        ELSE NULL
    END INTO v_agencia;
    
    IF v_agencia IS NULL THEN
        -- Simular error de no encontrado
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se ha encontrado ningún dato';
    END IF;
    
    RETURN v_agencia;
END$$

-- Función para determinar monto de consumos desde TOTAL_CONSUMOS
CREATE FUNCTION fn_obtener_consumos(p_id_huesped INT) 
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE v_total INT DEFAULT 0;
    
    SELECT COALESCE(MONTO_CONSUMOS, 0) INTO v_total
    FROM TOTAL_CONSUMOS
    WHERE ID_HUESPED = p_id_huesped;
    
    RETURN v_total;
END$$

DELIMITER ;


-- 3. Procedimiento Almacenado Principal

DELIMITER $$

CREATE PROCEDURE sp_calcular_pagos_diarios_v2(
    IN p_fecha_proceso DATE,
    IN p_tipo_cambio INT,
    IN p_fecha_referencia DATE
)
BEGIN
    DECLARE v_id_huesped INT;
    DECLARE v_nombre VARCHAR(100);
    DECLARE v_agencia VARCHAR(100);
    DECLARE v_alojamiento INT;
    DECLARE v_tours INT;
    DECLARE v_subtotal INT;
    DECLARE v_descuento_tours INT DEFAULT 0;
    DECLARE v_descuento_agencia INT DEFAULT 0;
    DECLARE v_total INT;
    DECLARE v_num_personas INT DEFAULT 1;
    DECLARE v_valor_persona INT DEFAULT 35000;
    
    DECLARE v_finished INT DEFAULT 0;
    DECLARE v_error_msg TEXT;
    
    -- Cursor para huéspedes con salida el día de proceso
    DECLARE cur_huespedes CURSOR FOR 
        SELECT DISTINCT ID_HUESPED 
        FROM CONSUMO 
        WHERE ID_HUESPED IN (340003, 340004, 340006, 340008, 340009);
    
    -- Manejador para cuando no hay más registros en el cursor
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_finished = 1;
    
    -- Manejador para errores SQL - CONTINUE para seguir con el siguiente huésped
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
        -- El error ya debería estar registrado por la función
        -- Continuamos con el siguiente huésped
    END;
    
    -- Limpiar tablas de resultados y errores
    TRUNCATE TABLE DETALLE_DIARIO_HUESPEDES;
    TRUNCATE TABLE REG_ERRORES;
    
    OPEN cur_huespedes;
    
    procesar_loop: LOOP
        FETCH cur_huespedes INTO v_id_huesped;
        
        IF v_finished = 1 THEN
            LEAVE procesar_loop;
        END IF;
        
        -- Obtener agencia (si hay error, la función retorna 'NO REGISTRA AGENCIA' y registra el error)
        SET v_agencia = fn_obtener_agencia(v_id_huesped);
        
        -- Obtener consumos (si no hay, retorna 0)
        SET v_tours = fn_obtener_consumos(v_id_huesped);
        
        -- Calcular alojamiento (simulado - en realidad vendría de otra tabla)
        SET v_alojamiento = 1000; -- Valor simulado
        
        -- Calcular subtotal: alojamiento + tours + (valor_persona * num_personas / tipo_cambio)
        SET v_subtotal = v_alojamiento + v_tours + ROUND((v_valor_persona * v_num_personas) / p_tipo_cambio);
        
        -- Calcular descuento de agencia (12% si es Viajes Alberti)
        IF v_agencia = 'VIAJES ALBERTI' THEN
            SET v_descuento_agencia = ROUND(v_subtotal * 0.12);
        ELSE
            SET v_descuento_agencia = 0;
        END IF;
        
        -- Calcular total: subtotal - descuento_tours - descuento_agencia
        SET v_total = v_subtotal - v_descuento_tours - v_descuento_agencia;
        
        -- Insertar en tabla de resultados (convertido a pesos chilenos)
        INSERT INTO DETALLE_DIARIO_HUESPEDES 
            (ID_HUESPED, NOMBRE, AGENCIA, ALOJAMIENTO, TOURS, SUBTOTAL_PAGO, 
             DESCUENTO_TOURS, DESCUENTO_AGENCIA, TOTAL, FECHA_PROCESO)
        VALUES (
            v_id_huesped,
            CONCAT('Huésped ', v_id_huesped), -- Nombre simulado
            v_agencia,
            v_alojamiento * p_tipo_cambio, -- Convertido a pesos
            v_tours * p_tipo_cambio, -- Convertido a pesos
            v_subtotal * p_tipo_cambio, -- Convertido a pesos
            v_descuento_tours * p_tipo_cambio,
            v_descuento_agencia * p_tipo_cambio,
            v_total * p_tipo_cambio,
            p_fecha_proceso
        );
        
    END LOOP;
    
    CLOSE cur_huespedes;
    
    -- Mostrar resultados
    SELECT * FROM DETALLE_DIARIO_HUESPEDES;
    SELECT * FROM REG_ERRORES;
    
END$$

DELIMITER ;

-- 4. Ejecución del Procedimiento Principal


CALL sp_calcular_pagos_diarios_v2('2021-08-18', 915, '2021-08-18');

-- Verificar resultados
SELECT * FROM DETALLE_DIARIO_HUESPEDES;
SELECT * FROM REG_ERRORES;
