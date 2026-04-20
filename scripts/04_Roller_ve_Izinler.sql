/* =========================================================
   04 - Roller ve Izinler (GRANT / DENY / REVOKE)
   Proje 3: Guvenlik ve Erisim Kontrolu
   -----------------------------------------
   "Least privilege" prensibi: her kullanici yalnizca isini yapacak
   kadar yetkiye sahip olmali. Bu script 4 rol olusturur ve izinleri
   sema/tablo/sutun seviyesinde dagitir.
   ========================================================= */

USE PersonelDB;
GO

-- ===========================
-- Database Rolleri (custom)
-- ===========================
IF DATABASE_PRINCIPAL_ID('rol_Admin')  IS NULL  CREATE ROLE rol_Admin;
IF DATABASE_PRINCIPAL_ID('rol_Bordro') IS NULL  CREATE ROLE rol_Bordro;
IF DATABASE_PRINCIPAL_ID('rol_IK')     IS NULL  CREATE ROLE rol_IK;
IF DATABASE_PRINCIPAL_ID('rol_Rapor')  IS NULL  CREATE ROLE rol_Rapor;
GO

-- Kullanicilari rollerine ata
ALTER ROLE rol_Admin  ADD MEMBER adminUser;
ALTER ROLE rol_Bordro ADD MEMBER bordroUser;
ALTER ROLE rol_IK     ADD MEMBER ikUser;
ALTER ROLE rol_Rapor  ADD MEMBER raporUser;
GO

-- ===========================
-- Izinler
-- ===========================

-- Admin: db_owner ekvivalani olmasin, ama her seyi yapsin
-- (ornek olarak sema bazinda full yetki)
GRANT CONTROL ON SCHEMA::ik        TO rol_Admin;
GRANT CONTROL ON SCHEMA::bordro    TO rol_Admin;
GRANT CONTROL ON SCHEMA::raporlama TO rol_Admin;

-- Bordro uzmanı: bordro sema'sinda tam yetki; ik'dan sadece Calisanlar okuma
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::bordro TO rol_Bordro;
GRANT SELECT                         ON ik.Calisanlar  TO rol_Bordro;
-- Ama TCKimlikNo'yu goremesin:
DENY  SELECT ON ik.Calisanlar (TCKimlikNo) TO rol_Bordro;

-- IK gorevlisi: ik sema'sinda okuma/guncelleme; bordro hic gormemeli
GRANT SELECT, UPDATE ON SCHEMA::ik     TO rol_IK;
DENY  SELECT         ON SCHEMA::bordro TO rol_IK;   -- EN GUCLU: tablo DENY
-- IK maaslari gormemeli; ozellikle acikca da yasak
DENY SELECT ON bordro.Maaslar TO rol_IK;

-- Rapor kullanicisi: tum tablolara SELECT; hassas sutunlara DENY
GRANT SELECT ON SCHEMA::ik     TO rol_Rapor;
GRANT SELECT ON SCHEMA::bordro TO rol_Rapor;
DENY  SELECT ON ik.Calisanlar (TCKimlikNo) TO rol_Rapor;
DENY  SELECT ON bordro.Maaslar (BrutMaas, NetMaas) TO rol_Rapor;
GO

-- ===========================
-- Raporlama icin guvenli bir VIEW
-- Hassas sutunlari disarida birakir; raporUser bunu kullanabilir
-- ===========================
CREATE OR ALTER VIEW raporlama.vwCalisanOzet AS
SELECT c.CalisanID, c.Ad, c.Soyad, c.Email, c.IseBaslama, c.Aktif,
       d.Ad AS Departman, u.Ad AS Unvan
FROM ik.Calisanlar c
JOIN ik.Departmanlar d ON d.DepartmanID = c.DepartmanID
JOIN ik.Unvanlar     u ON u.UnvanID     = c.UnvanID;
GO

GRANT SELECT ON raporlama.vwCalisanOzet TO rol_Rapor;
GO

-- ===========================
-- Mevcut izinleri listele (dokumantasyon amacli)
-- ===========================
SELECT
    dp.name           AS principal_name,
    dp.type_desc      AS principal_type,
    perm.permission_name,
    perm.state_desc   AS state,
    OBJECT_SCHEMA_NAME(perm.major_id) + '.' + OBJECT_NAME(perm.major_id) AS object_name,
    COL_NAME(perm.major_id, perm.minor_id) AS column_name,
    perm.class_desc
FROM sys.database_permissions perm
JOIN sys.database_principals  dp ON dp.principal_id = perm.grantee_principal_id
WHERE dp.name LIKE 'rol_%'
ORDER BY dp.name, object_name;
GO

PRINT '>> Roller ve izinler kurgulandi. (Admin / Bordro / IK / Rapor)';
GO
