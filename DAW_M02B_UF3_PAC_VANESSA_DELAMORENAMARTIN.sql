---------------------------------------------------------------
-- 1) REPASO SQL. TABLAS Y VISTAS ------------------
---------------------------------------------------------------
-- A lo largo del codigo voy haciendo varias comprobaciones para comprobar las actualizaciones de la vista expediente,
-- para el trigger hago comprobacion de que esta bien asociado a la tabla, al final hay una comprobacion de la nota media de las asignaturas
-- que he usado para comprobar los valores junto con la vista expediente.
--1.1) AÑADIR CAMPOS A LAS TABLAS
-- Tabla ASIGNATURAS
ALTER TABLE ASIGNATURAS ADD NOM_PROFE VARCHAR (50);

ALTER TABLE ASIGNATURAS ADD APRO_UFS NUMBER;

ALTER TABLE ASIGNATURAS ADD NOTA_MEDIA_ASIG NUMBER (4,2);

-- Tabla UFS
ALTER TABLE UFS ADD NOTA_MEDIA NUMBER (4,2);

ALTER TABLE UFS ADD NOTA_FINAL_UF INT;

ALTER TABLE UFS ADD STAF_UF VARCHAR(10);

--1.2) CREACION DE VISTAS
CREATE OR REPLACE VIEW EXPEDIENTE AS SELECT  
    ASIGNATURAS.ABV_ASIG,  
    ASIGNATURAS.DES_ASIG,  
    ROUND(num_pacs_ent / tot_pacs_uf * 100,2) AS PORC_PACS_ENTRE,  
    UFS.NOTA_MEDIA_PACS,  
    UFS.NOTA_EXAM,  
    UFS.CONV_EXAM,  
    UFS.NOTA_MEDIA,  
    UFS.NOTA_FINAL_UF,  
    UFS.STAF_UF  
    FROM ASIGNATURAS INNER JOIN UFS ON ASIGNATURAS.COD_ASIG = UFS.COD_ASIG;
-- VISTA INNER JOIN DE ASIGNATURAS Y UFS, QUE PERMITE HACER SELECT DESPUES 
-- Y VER TODAS LAS NOTAS MEDIAS.
 SELECT * FROM EXPEDIENTE;-- select para comprobar que la vista se ha creado correctamente.

--1.3) ACTUALIZAR REGISTROS

UPDATE ASIGNATURAS   
    SET NOM_PROFE = 'Emilio Saurina'  
    WHERE cod_asig = 'ICB0102A';

UPDATE ASIGNATURAS  
    SET NOM_PROFE = 'Emilio Saurina'  
    WHERE cod_asig = 'ICB0102B';
-- Se actualizan los dos registros para las asignaturas ICB0102A/ICB0102B
---------------------------------------------------------------
-- 2) PROCEDIMIENTOS ----------------------------------
---------------------------------------------------------------
-- CREAR PROCEDIMIENTO "P_NOTA_MEDIA_ASIG"
--Procedimiento para calcular la nota media segun las notas medias de UFS.
-- Se pasan las variables de entrada y salida. 
-- Uso un bucle for para recorrer todas las UFS de cada asginatura, 
-- evaluando en cada if los casos correspondientes; además evalua si todas las ufs
-- han sido aprobadas guardando en valor en la variable V_APROBADAS.
-- Si no estan todas aprobadas le doy el valor null a la nota media de la asignatura.
-- Finalmente realizo el update para actualizar la tabla (en un principio al hacer
-- el procedimiento no lo puse, y me di cuenta despues de que no me lo estaba actualizando)
CREATE OR REPLACE PROCEDURE P_CALCULAR_NOTA_MEDIA_ASIG(  
    VIN_COD_ASIG IN VARCHAR,  
    VOUT_APRO_UFS OUT INT,  
    VOUT_NOTA_MEDIA_ASIG OUT NUMBER  
)  
AS   
	V_APROBADAS NUMBER:=0;  
	V_PONDERADA NUMBER:=0;  
	V_TOTAL_UFS NUMBER:=0; 
    V_NO_APROBADAS NUMBER := 0;
BEGIN  
	SELECT COUNT(*) INTO V_TOTAL_UFS FROM UFS WHERE COD_ASIG= VIN_COD_ASIG;  -- SELECT PARA OBTENER EL NUMERO TOTAL DE UFS PARA CADA ASIGNATURA
	FOR UF IN (SELECT * FROM UFS WHERE COD_ASIG=VIN_COD_ASIG)  
	LOOP  
		IF UF.NOTA_FINAL_UF >=5 THEN  
			V_APROBADAS:=V_APROBADAS+1;  
			V_PONDERADA:=V_PONDERADA+(UF.NOTA_FINAL_UF*UF.PONDERA_UF);  
		
        ELSE V_NO_APROBADAS:= V_NO_APROBADAS + 1;
        END IF;
	END LOOP;  
	IF V_NO_APROBADAS=0 THEN
        IF V_APROBADAS=V_TOTAL_UFS THEN  
            VOUT_APRO_UFS:=V_APROBADAS;  
            VOUT_NOTA_MEDIA_ASIG:=V_PONDERADA/V_TOTAL_UFS; 
        
        ELSE   
            VOUT_NOTA_MEDIA_ASIG := NULL;  
            VOUT_APRO_UFS:= V_APROBADAS;
        END IF;
    END IF;
    
    UPDATE asignaturas SET NOTA_MEDIA_ASIG = VOUT_NOTA_MEDIA_ASIG
    WHERE COD_ASIG = VIN_COD_ASIG;
END;  
/
---------------------------------------------------------------
-- 3) FUNCIONES ------------------------------------------
---------------------------------------------------------------
-- CREAR FUNCION "F_NOTA_MEDIA_UF
-- La funcion establece la nota media de cada UF, segun sea el caso:
-- extraordinaria, ordinaria o proyecto (en este ultimo he utilizado un else 
-- por ser la ultima condición)
-- Por último el return, para devolver la nota media de la uf (utilizada en el trigger)
CREATE OR REPLACE FUNCTION F_NOTA_MEDIA_UF (   
    VIN_CONV_EXAM IN VARCHAR2,   
    VIN_NUM_PACS_ENT IN NUMBER,   
    VIN_MIN_PACS_ENT IN NUMBER,   
    VIN_NOTA_MEDIA_PACS IN NUMBER,   
    VIN_NOTA_EXAM IN NUMBER   
)   
    RETURN NUMBER AS    
	V_NOTA_MEDIA NUMBER;   
BEGIN   
	IF VIN_CONV_EXAM ='EXTRAORDINARIA' THEN   
		V_NOTA_MEDIA:=VIN_NOTA_EXAM;
	ELSIF VIN_CONV_EXAM ='ORDINARIA' THEN   
		IF VIN_NUM_PACS_ENT < VIN_MIN_PACS_ENT    
        OR VIN_NOTA_EXAM < 4.75 OR (VIN_NOTA_MEDIA_PACS < 7 AND VIN_NOTA_EXAM BETWEEN 4.75 AND 4.89)THEN   
			V_NOTA_MEDIA:=VIN_NOTA_MEDIA_PACS * 0.4;
        ELSE V_NOTA_MEDIA:=VIN_NOTA_MEDIA_PACS * 0.4 + VIN_NOTA_EXAM * 0.6; 
		END IF;   
	ELSE V_NOTA_MEDIA:=VIN_NOTA_EXAM;   
	END IF;
RETURN V_NOTA_MEDIA;
END; 
/

SELECT * FROM EXPEDIENTE;
---------------------------------------------------------------
-- 4) TRIGGERS ---------------------------------------------
---------------------------------------------------------------
-- CREAR TRIGGER "T_ACTUALIZA_NOTA_FINAL"
-- Llamo a la función en el trigger para calcular la nota media de cada uf, 
-- y de esta forma poder establecer la nota final.
-- Utilizo el condicional If para establecer la nota de forma correcta en base a 
-- las especificaciones.
-- Por ultimo hago un Case para actualizar la columna Staf_uf en base a la nota media
-- como aprobado,suspenso o pendiente.
CREATE OR REPLACE TRIGGER T_ACTUALIZA_NOTA_FINAL
    BEFORE UPDATE ON UFS
    FOR EACH ROW
    DECLARE
    V_conv_exam VARCHAR2(15);
    V_NOTA_MEDIA NUMBER;
    BEGIN
    :NEW.NOTA_MEDIA:=F_NOTA_MEDIA_UF(:NEW.conv_exam,:NEW.NUM_PACS_ENT,:NEW.MIN_PACS_ENT,:NEW.NOTA_MEDIA_PACS,:NEW.NOTA_EXAM);
    :NEW.NOTA_FINAL_UF:=:NEW.NOTA_FINAL_UF;
    V_conv_exam := :NEW.conv_exam;

    IF V_conv_exam='EXTRAORDINARIA' THEN
        IF :NEW.NOTA_MEDIA BETWEEN 4.5 AND 4.74 THEN
        :NEW.NOTA_FINAL_UF:=TRUNC(:NEW.NOTA_MEDIA);
        ELSE :NEW.NOTA_FINAL_UF:=ROUND (:NEW.NOTA_MEDIA,1);
        END IF;
    END IF;
    IF V_conv_exam='ORDINARIA' THEN

            IF :NEW.NOTA_MEDIA BETWEEN 4.5 AND 4.74 THEN
            :NEW.NOTA_FINAL_UF:=TRUNC(:NEW.NOTA_MEDIA);
            END IF;
            IF :NEW.NOTA_MEDIA BETWEEN 4.75 AND 4.89 AND :NEW.NOTA_MEDIA_PACS<7 THEN
            :NEW.NOTA_FINAL_UF:=TRUNC(:NEW.NOTA_MEDIA);
            END IF;
            IF :NEW.NOTA_MEDIA BETWEEN 4.75 AND 4.89 AND :NEW.NOTA_MEDIA_PACS>7 THEN
            :NEW.NOTA_FINAL_UF:=ROUND (:NEW.NOTA_MEDIA,1);
            END IF;
            IF :NEW.NOTA_MEDIA >= 4.9 THEN 
            :NEW.NOTA_FINAL_UF:=ROUND (:NEW.NOTA_MEDIA,1);
             ELSE
            :NEW.NOTA_FINAL_UF := ROUND(:NEW.NOTA_MEDIA);
            END IF;
        
    END IF;
    IF V_conv_exam='PROYECTO' THEN
        
            IF :NEW.NOTA_MEDIA BETWEEN 4.5 AND 4.99 THEN 
            :NEW.NOTA_FINAL_UF:=TRUNC(:NEW.NOTA_MEDIA);
            ELSE :NEW.NOTA_FINAL_UF:=ROUND(:NEW.NOTA_MEDIA,1);
            END IF;
    END IF;
 
    CASE
    
     WHEN :NEW.NOTA_FINAL_UF<5 THEN :NEW.STAF_UF:='SUSPENSO';  
     WHEN :NEW.NOTA_FINAL_UF>=5 THEN :NEW.STAF_UF:='APROBADO';
     WHEN :NEW.NOTA_FINAL_UF IS NULL THEN :NEW.STAF_UF:='PENDIENTE'; 
     END CASE;
  
    END;
    /


-- comprobar que trigger esta bien asociado a tabla ufs
SELECT * FROM ALL_TRIGGERS WHERE TABLE_NAME = 'UFS';

---------------------------------------------------------------
-- 5) BLOQUES ANONIMOS ----------------------------?
---------------------------------------------------------------
--5.1) Actualizar las nota media de todas las UFs
-- Bloque anónimo en el uso un cursor con un bucle for para actualizar cada registro
-- de la tabla utlizando la funcion (la llamo dentro del bucle) y por tanto utilizando el
-- trigger, que se dispara cada vez que se realiza una actualizacion de la nota media;

DECLARE
    CURSOR C_UFS IS
    SELECT CONV_EXAM, NUM_PACS_ENT, MIN_PACS_ENT, NOTA_MEDIA_PACS, NOTA_EXAM
    FROM UFS
    FOR UPDATE OF NOTA_MEDIA;
    BEGIN
    FOR R_UF IN C_UFS LOOP
    UPDATE UFS SET NOTA_MEDIA = F_NOTA_MEDIA_UF(r_uf.CONV_EXAM, r_uf.NUM_PACS_ENT, r_uf.MIN_PACS_ENT, r_uf.NOTA_MEDIA_PACS, r_uf.NOTA_EXAM) WHERE CURRENT OF c_ufs;
    END LOOP;
END;
/
SELECT * FROM EXPEDIENTE; -- comprobacion valores vista expediente
--5.2) Actualizar las nota media de todas las asignaturas
-- Actualiza las columnas apro_ufs y nota_media_asig llamando al procedimiento, 
-- usando un bucle para iterar en cada registro y actualizarlo.
--^Por ultimo uso el commit para guardas estos cambios.
DECLARE
    CURSOR C_ASIGNATURAS IS
    SELECT COD_ASIG, NOTA_MEDIA_ASIG, APRO_UFS
    FROM ASIGNATURAS
    FOR UPDATE OF APRO_UFS, NOTA_MEDIA_ASIG;
    V_COD_ASIG VARCHAR2(10);
    V_NOTA_MEDIA_ASIG NUMBER;
    V_APRO_UFS NUMBER;
    BEGIN
    FOR R_ASIGNATURAS IN C_ASIGNATURAS LOOP
    P_NOTA_MEDIA_ASIG(R_ASIGNATURAS.COD_ASIG, V_APRO_UFS, V_NOTA_MEDIA_ASIG);
    UPDATE ASIGNATURAS
    SET APRO_UFS = V_APRO_UFS,
    NOTA_MEDIA_ASIG = V_NOTA_MEDIA_ASIG
    WHERE CURRENT OF C_ASIGNATURAS;
  END LOOP;
  COMMIT;
END;
/

--5.3) Crear un bloque anonimo que calcule la nota media final del ciclo
-- Primero pongo set server output on para permitir la salida de datos por consola.
-- El cursor recorre las notas medias de las asignaturas y las ponderaciones, si la nota es NULL
-- aumento el valor de ASIG_FALTANTE; de esta forma esta asignaturas no se contaran para la nota media 
-- del ciclo.
-- Si por el contrario no hay valor null, se añadira el valor a la variable de la nota media del ciclo.
-- Si no falta ninguna asignatura se mostrara solamente la nota media del ciclo, si no
-- mostrara las asignaturas que faltan y la nota media calculada con todas las demas asignaturas.
SET SERVEROUTPUT ON;
DECLARE
    V_NOTA_MEDIA_CICLO NUMBER := 0;
    V_ASIG_FALTANTE NUMBER := 0;
    CURSOR C_ASIGNATURAS IS SELECT NOTA_MEDIA_ASIG, PONDERA_ASIG FROM ASIGNATURAS;
     R_ASIGNATURAS C_ASIGNATURAS%ROWTYPE;
BEGIN
    FOR R_ASIGNATURAS IN C_ASIGNATURAS LOOP
    IF R_ASIGNATURAS.NOTA_MEDIA_ASIG IS NULL THEN
    V_ASIG_FALTANTE := V_ASIG_FALTANTE + 1;
    ELSE
    V_NOTA_MEDIA_CICLO := V_NOTA_MEDIA_CICLO + (R_ASIGNATURAS.NOTA_MEDIA_ASIG * R_ASIGNATURAS.PONDERA_ASIG);
    END IF;
    END LOOP;
    IF V_ASIG_FALTANTE = 0 THEN
    DBMS_OUTPUT.PUT_LINE('El ciclo se ha terminado con una nota media de: ' || ROUND(V_NOTA_MEDIA_CICLO, 2));
    ELSE
    DBMS_OUTPUT.PUT_LINE('A falta de ' || V_ASIG_FALTANTE || ' asignaturas por aprobar. La nota media del ciclo es de: ' || ROUND(V_NOTA_MEDIA_CICLO, 2));
    END IF;
END;
/

--Esto es para que salga la tabla expediente--
    SELECT * FROM EXPEDIENTE; -- PARA VER LA TABLA EXPEDIENTE COMPLETADA
    SELECT NOTA_MEDIA_ASIG FROM ASIGNATURAS; -- COMPROBACION NOTA MEDIA ASIGNATURAS
